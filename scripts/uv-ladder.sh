#!/usr/bin/env bash
# uv-ladder.sh — Automated undervolt cliff finder for the XPS 9570 (i7-8750H)
#
# Walks core/cache/gpu offsets deeper in 10mV steps. For every step it:
#   1. writes a fsynced state file (/var/lib/uv-ladder/state) BEFORE applying,
#      so a hard crash leaves behind exactly which offset killed the machine
#   2. applies the offset live (MSR, volatile — gone on reboot/sleep)
#   3. verifies the readback matches (catches firmware clamping)
#   4. runs the full-system stress (scripts/undervolt-stress.sh)
#   5. runs an automated suspend/resume cycle (RTC wake after 3 min),
#      re-applies the offset and stress-tests again (resume = classic crash point)
#
# After a crash: reboot boots at the config value (-150) because MSR voltage
# resets. Then run `report` — it tells you the crash step and what to commit.
#
# Usage:
#   sudo ./scripts/uv-ladder.sh run [start_mv] [end_mv] [duration_s]
#       defaults: continue from last stable +10, end 200, 300s per step
#   sudo ./scripts/uv-ladder.sh report
#   sudo ./scripts/uv-ladder.sh reset

set -u

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
STRESS="$SCRIPT_DIR/undervolt-stress.sh"
STATE_DIR=/var/lib/uv-ladder
STATE=$STATE_DIR/state
HISTORY=$STATE_DIR/history.log
LADDER_DIR=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
say() { echo -e "$1"; }

state_write() {  # $1 step_mv  $2 last_stable_mv  $3 phase
    mkdir -p "$STATE_DIR"
    cat > "$STATE_DIR/.state.tmp" <<EOF
ts=$(date +%s)
step_mv=$1
last_stable_mv=$2
phase=$3
EOF
    sync "$STATE_DIR/.state.tmp" 2>/dev/null || sync
    mv "$STATE_DIR/.state.tmp" "$STATE"
    sync
}

state_get() { grep -oP "^$1=\K.*" "$STATE" 2>/dev/null || echo ""; }

preflight() {
    [[ $EUID -eq 0 ]] || { say "Run with sudo."; exit 1; }
    command -v undervolt >/dev/null 2>&1 || { say "undervolt binary not found"; exit 1; }
    [[ -x "$STRESS" ]] || { say "Missing $STRESS"; exit 1; }
    [[ -w /sys/class/rtc/rtc0/wakealarm ]] || { say "No writable /sys/class/rtc/rtc0/wakealarm"; exit 1; }
}

apply_offsets() {  # $1 = positive mv
    undervolt --cache "-$1" --core "-$1" --gpu "-$1" > "${LADDER_DIR:-/tmp}/apply-$1.log" 2>&1
}

readback_ok() {  # $1 = positive mv; true if core readback matches
    local want="-$1" got
    got=$(undervolt -r 2>/dev/null | grep -oP '^core:\s*\K-?[0-9.]+')
    [[ -n "$got" ]] || return 1
    awk -v g="$got" -v w="$want" 'BEGIN{d=g-w; if(d<0)d=-d; exit !(d<=0.5)}'
}

peak_core_of() {  # $1 = step outdir
    awk -F, 'NR>1 && $2~/^[0-9]/ {if($2+0>m)m=$2+0} END{printf "%.0f", m+0}' "$1/temps.csv" 2>/dev/null || echo "?"
}

run_stress() {  # $1 outdir  $2 duration; rc: 0 stable, 2 stable+throttle warn, 1 FAIL
    mkdir -p "$1"
    "$STRESS" "$2" "$1" > "$1/console.log" 2>&1
}

resume_test() {  # $1 = mv; rc: 0 pass, 1 fail
    state_write "$1" "$PREV" resume
    echo +180 > /sys/class/rtc/rtc0/wakealarm
    say "  suspend — RTC wake in 3 min..."
    systemctl suspend
    sleep 10
    local attempt got
    for attempt in 1 2 3; do
        apply_offsets "$1"
        sleep 1
        undervolt -r > "$LADDER_DIR/readback-$1-$attempt.log" 2>&1
        readback_ok "$1" && break
        got=$(grep -oP '^core:\s*\K-?[0-9.]+' "$LADDER_DIR/readback-$1-$attempt.log" | head -1)
        say "  attempt $attempt: readback shows '${got:-<empty>}' (want -$1)"
        sleep 3
    done
    if ! readback_ok "$1"; then
        say "  ${RED}readback mismatch after resume — see readback-$1-*.log${NC}"
        return 1
    fi
    run_stress "$LADDER_DIR/step-$1-resume" 60
}

log_step() {  # $1 status  $2 mv  $3 peakC  $4 phase
    printf '%s %s -%s peak=%sC phase=%s\n' "$(date '+%F %T')" "$1" "$2" "$3" "$4" >> "$HISTORY"
}

cmd_run() {
    preflight
    START="${1:-}"; END="${2:-200}"; DUR="${3:-300}"; STEP=10
    LAST=$(state_get last_stable_mv)

    if [[ -z "$START" ]]; then
        if [[ -n "$LAST" && "$LAST" != "0" ]]; then
            START=$((LAST + STEP))
            say "Resuming ladder from last stable -$LAST → starting -$START"
        else
            START=160
        fi
    fi
    [[ "$LAST" == "$END" ]] && { say "Already walked to -$END without a cliff. Commit -$END or extend END."; exit 0; }

    LADDER_DIR="$SCRIPT_DIR/../stress-results/uv-ladder-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$LADDER_DIR"
    say "${CYAN}Ladder: -${START} → -${END} mV, ${DUR}s heavy + suspend/resume per step${NC}"
    say "${CYAN}Results → $LADDER_DIR${NC}"

    [[ -n "$LAST" && "$LAST" != "0" ]] && PREV=$LAST || PREV=$((START - STEP))
    DIED_AT=""

    trap 'state_write 0 "$PREV" interrupted; say "Interrupted — last stable -$PREV. Run \`report\` anytime."; exit 130' INT TERM

    for X in $(seq "$START" "$STEP" "$END"); do
        say "${CYAN}── Testing -$X mV ──${NC}"
        state_write "$X" "$PREV" stress

        apply_offsets "$X"
        if ! readback_ok "$X"; then
            say "${YELLOW}Machine refuses/clamps beyond -$X — stopping here.${NC}"
            log_step CLAMP "$X" "?" apply
            break
        fi

        run_stress "$LADDER_DIR/step-$X-heavy" "$DUR"
        rc=$?
        if (( rc == 1 )); then
            say "${RED}FAILED under heavy load at -$X${NC}"
            log_step FAIL "$X" "$(peak_core_of "$LADDER_DIR/step-$X-heavy")" heavy
            DIED_AT=$X
            break
        fi
        say "  heavy load OK (peak $(peak_core_of "$LADDER_DIR/step-$X-heavy")°C, rc=$rc)"

        resume_test "$X"
        rc=$?
        if (( rc == 1 )); then
            say "${RED}FAILED suspend/resume at -$X${NC}"
            log_step FAIL "$X" "$(peak_core_of "$LADDER_DIR/step-$X-resume")" resume
            DIED_AT=$X
            break
        fi
        say "  suspend/resume OK"

        PREV=$X
        state_write 0 "$PREV" idle
        log_step PASS "$X" "$(peak_core_of "$LADDER_DIR/step-$X-heavy")" heavy
        say "${GREEN}  -$X mV stable${NC}"
    done

    state_write 0 "$PREV" done
    say ""
    say "═══════════════════════════════════════════════════════════"
    if [[ -n "$DIED_AT" ]]; then
        say "${GREEN}LAST STABLE: -${PREV} mV${NC}   (cliff at -${DIED_AT})"
        say "Commit to modules/hardware.nix:"
        say "  coreOffset = -${PREV};"
        say "  gpuOffset  = -${PREV};"
    else
        say "${GREEN}No cliff found through -${END} mV${NC} — last applied -${PREV}."
        say "Commit -$PREV only if you accept the risk; MSR voltage resets on reboot until you switch."
    fi
    say "Make it permanent:  sudo nixos-rebuild switch --flake .#hippo-xps"
    say "Until then, the applied value vanishes on reboot/sleep (config stays at -150)."
    say "═══════════════════════════════════════════════════════════"
}

cmd_report() {
    [[ -f "$STATE" ]] || { say "No state file — nothing to report."; exit 0; }
    STEP=$(state_get step_mv); LAST=$(state_get last_stable_mv)
    TS=$(state_get ts); PHASE=$(state_get phase)
    BOOT=$(awk '/^btime/{print $2}' /proc/stat)

    if [[ -n "$STEP" && "$STEP" != "0" ]]; then
        if [[ -n "$TS" && "$TS" -lt "$BOOT" ]]; then
            say "${RED}CRASH DETECTED at -${STEP} mV (phase: ${PHASE})${NC}"
            say "${GREEN}LAST STABLE: -${LAST} mV${NC}"
            say "Commit to modules/hardware.nix:"
            say "  coreOffset = -${LAST};"
            say "  gpuOffset  = -${LAST};"
            say "then: sudo nixos-rebuild switch --flake .#hippo-xps"
        else
            say "Step -${STEP} (${PHASE}) was recorded during the CURRENT boot —"
            say "the ladder is still running, or you rebooted without a crash."
        fi
    elif [[ -n "$LAST" && "$LAST" != "0" ]]; then
        say "No crash pending. ${GREEN}Last stable: -${LAST} mV${NC}"
        say "Commit with the same two lines in modules/hardware.nix, then switch."
    else
        say "No completed steps recorded yet."
    fi
    [[ -f "$HISTORY" ]] && { say ""; say "History:"; tail -20 "$HISTORY"; }
}

cmd_reset() {
    rm -f "$STATE"
    say "State cleared."
}

case "${1:-}" in
    run)    shift; cmd_run "$@" ;;
    report) cmd_report ;;
    reset)  cmd_reset ;;
    *)      say "Usage: sudo $0 run [start_mv] [end_mv] [duration_s] | report | reset" ;;
esac
