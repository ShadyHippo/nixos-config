#!/usr/bin/env bash
# undervolt-stress.sh — Full-system stress test for undervolt validation
#
# Loads CPU (all cores, matrixprod), RAM (75% in 4 workers) and GPU
# (glmark2, 4K fullscreen, vblank off) simultaneously, logs temperatures
# every 5s, and reports peak temps + a pass/fail verdict.
#
# Fans are NOT touched: on this machine (XPS 9570) the EC owns fan control
# and reverts all software writes within ~1s. Run long enough for the EC's
# own curve to ramp, or adjust the fan behavior in BIOS.
#
# Usage: sudo ./scripts/undervolt-stress.sh [duration_seconds] [output_dir]
#   Default: 300s, results in ./stress-results/<timestamp>/

set -euo pipefail

DURATION="${1:-300}"
OUTDIR="${2:-./stress-results/$(date +%Y%m%d-%H%M%S)}"
mkdir -p "$OUTDIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

log()  { echo -e "${CYAN}[$(date +%T)]${NC} $*" | tee -a "$OUTDIR/run.log"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*" | tee -a "$OUTDIR/run.log"; }
fail() { echo -e "${RED}[FAIL]${NC} $*" | tee -a "$OUTDIR/run.log"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*" | tee -a "$OUTDIR/run.log"; }

# ── Preflight ────────────────────────────────────────────────────────────────
for cmd in stress-ng sensors; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "Missing: $cmd"; exit 1; }
done

CORES=$(nproc)
MAX_TEMP_C=95          # warn: throttle zone
CRIT_TEMP_C=100        # abort: hardware trip point
LOG_INTERVAL=5

log "═══════════════════════════════════════════════════════════"
log " Undervolt Stress Test — ${DURATION}s, ${CORES} cores"
log " Results → $OUTDIR"
log "═══════════════════════════════════════════════════════════"

log "Recording baseline sensor readings..."
sensors > "$OUTDIR/sensors-baseline.txt" 2>&1
cat "$OUTDIR/sensors-baseline.txt"

# ── CPU governor: performance for the test, restore on exit ─────────────────
ORIGINAL_GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "powersave")
log "CPU governor: ${ORIGINAL_GOVERNOR} → performance"
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance > "$g" 2>/dev/null || true
done

cleanup() {
    for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        echo "$ORIGINAL_GOVERNOR" > "$g" 2>/dev/null || true
    done
}
trap cleanup EXIT

# ── Temperature monitor (background) ─────────────────────────────────────────
TEMP_LOG="$OUTDIR/temps.csv"
echo "elapsed_s,core_max_c,package_c" > "$TEMP_LOG"

monitor_temps() {
    local elapsed=0 core pkg
    while (( elapsed < DURATION )); do
        core=$(sensors 2>/dev/null | grep -oP 'Core \d+:\s+\+\K[0-9.]+' | sort -rn | head -1)
        pkg=$(sensors 2>/dev/null | grep -oP 'Package id 0:\s+\+\K[0-9.]+' | head -1)
        echo "${elapsed},${core:-N/A},${pkg:-N/A}" >> "$TEMP_LOG"

        if [[ "$core" =~ ^[0-9]+$ ]]; then
            if (( core >= CRIT_TEMP_C )); then
                fail "CRITICAL: ${core}°C — aborting test"
                kill -- -$$ 2>/dev/null || true
                exit 1
            elif (( core >= MAX_TEMP_C )); then
                warn "THROTTLE ZONE: ${core}°C"
            fi
        fi
        sleep "$LOG_INTERVAL"
        elapsed=$(( elapsed + LOG_INTERVAL ))
    done
}

# ── CPU stress ───────────────────────────────────────────────────────────────
stress_cpu() {
    log "CPU: stress-ng ${CORES} workers, matrixprod, ${DURATION}s"
    stress-ng --cpu "$CORES" \
              --cpu-method matrixprod \
              --cpu-load 100 \
              --timeout "${DURATION}s" \
              --metrics-brief --times \
              --yaml "$OUTDIR/stress-cpu.yaml" \
              > "$OUTDIR/stress-cpu.log" 2>&1 &
    CPU_PID=$!
}

# ── RAM stress ───────────────────────────────────────────────────────────────
stress_ram() {
    local vm_count=$(( CORES / 2 )); (( vm_count < 1 )) && vm_count=1
    log "RAM: stress-ng ${vm_count} workers @ 75% mem, ${DURATION}s"
    stress-ng --vm "$vm_count" \
              --vm-bytes 75% \
              --vm-method all \
              --vm-keep \
              --timeout "${DURATION}s" \
              --metrics-brief --times \
              --yaml "$OUTDIR/stress-ram.yaml" \
              > "$OUTDIR/stress-ram.log" 2>&1 &
    RAM_PID=$!
}

# ── GPU stress ───────────────────────────────────────────────────────────────
# glmark2 renders on the real user's Wayland session (root has no display).
# --run-forever + timeout: timeout kills it at DURATION, exit 124 = expected.
stress_gpu() {
    command -v glmark2 >/dev/null 2>&1 || { warn "glmark2 not found — GPU stress skipped"; GPU_PID=""; return 0; }

    local real_user="${SUDO_USER:-$USER}" uid="" sock=""
    uid=$(id -u "$real_user" 2>/dev/null || true)
    if [[ -n "$uid" && -d "/run/user/${uid}" ]]; then
        local s
        for s in "/run/user/${uid}"/wayland-*; do
            [[ -S "$s" ]] && { sock=$(basename "$s"); break; }
        done
    fi
    if [[ -z "$sock" ]]; then
        warn "No Wayland socket found — GPU stress skipped"
        GPU_PID=""
        return 0
    fi

    log "GPU: glmark2 4K fullscreen, WAYLAND_DISPLAY=${sock}, ${DURATION}s"
    sudo -u "$real_user" \
        WAYLAND_DISPLAY="$sock" \
        XDG_RUNTIME_DIR="/run/user/${uid}" \
        vblank_mode=0 \
        timeout "${DURATION}s" glmark2 --fullscreen --run-forever \
        > "$OUTDIR/stress-gpu.log" 2>&1 &
    GPU_PID=$!
}

# ── Run everything ───────────────────────────────────────────────────────────
monitor_temps &
MONITOR_PID=$!

stress_cpu
stress_ram
stress_gpu

# ── Wait for workers; timeout-kill (124) is expected for glmark2 ─────────────
FAIL=0
for pid_name in CPU_PID RAM_PID GPU_PID; do
    pid="${!pid_name:-}"
    [[ -z "$pid" ]] && continue
    rc=0
    wait "$pid" || rc=$?
    if (( rc == 0 )); then
        pass "${pid_name} completed cleanly"
    elif (( rc == 124 )); then
        log "${pid_name} ended via timeout (expected)"
    else
        fail "${pid_name} exited with status ${rc}"
        FAIL=1
    fi
done
kill "$MONITOR_PID" 2>/dev/null || true

# ── Post-test ────────────────────────────────────────────────────────────────
log ""
log "═══════════════════════════════════════════════════════════"
log " Post-test sensor readings"
log "═══════════════════════════════════════════════════════════"
sensors > "$OUTDIR/sensors-final.txt" 2>&1
cat "$OUTDIR/sensors-final.txt"

PEAK_CORE=0
PEAK_PKG=0
if [[ -s "$TEMP_LOG" ]]; then
    PEAK_CORE=$(awk -F, 'NR>1 && $2~/^[0-9]/ {if($2+0>m)m=$2+0} END{printf "%.0f", m}' "$TEMP_LOG")
    PEAK_PKG=$(awk -F, 'NR>1 && $3~/^[0-9]/ {if($3+0>m)m=$3+0} END{printf "%.0f", m}' "$TEMP_LOG")
    log ""
    log "Peak core temp:  ${PEAK_CORE}°C"
    log "Peak package:    ${PEAK_PKG}°C"
fi

log ""
if (( FAIL )); then
    fail "TEST FAILED — a stress worker exited unexpectedly"
    log "Review logs in $OUTDIR for details"
    exit 1
elif (( PEAK_CORE >= MAX_TEMP_C )); then
    warn "TEST PASSED with warnings — temps reached the throttle zone"
    exit 2
else
    pass "STABLE — full CPU+RAM+GPU load for ${DURATION}s, peak ${PEAK_CORE}°C"
    exit 0
fi
