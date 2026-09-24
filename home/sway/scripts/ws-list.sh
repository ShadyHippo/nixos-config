#!/usr/bin/env bash
# JSON list of leaf windows on the focused workspace for the menu's window
# section. Workspace identity comes from get_workspaces (stable while the
# menu holds keyboard focus — get_tree's focused con is NOT: it disappears,
# which is what emptied the section after ~1s in the first implementation).
set -euo pipefail

python3 - <<'EOF'
import json
import subprocess


def tree(kind):
    return json.loads(subprocess.check_output(["swaymsg", "-t", kind]))


workspaces = tree("get_workspaces")
focused = next((w["name"] for w in workspaces if w["focused"]), None)
windows = []

if focused is not None:
    def walk(node, ws):
        here = node.get("name") if node.get("type") == "workspace" else ws
        kids = node.get("nodes", []) + node.get("floating_nodes", [])
        if not kids and here == focused and (node.get("app_id") or node.get("window_properties")):
            windows.append({
                "id": node["id"],
                "title": node.get("name") or node.get("app_id") or "",
                "app": node.get("app_id")
                or (node.get("window_properties") or {}).get("class")
                or "",
            })
        for kid in kids:
            walk(kid, here)

    walk(tree("get_tree"), None)

print(json.dumps(windows))
EOF
