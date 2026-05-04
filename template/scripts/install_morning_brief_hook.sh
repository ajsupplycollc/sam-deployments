#!/bin/bash
# Install the morning-brief SessionStart hook into the client's Claude Code settings.
# Idempotent — safe to re-run.
#
# Usage: bash install_morning_brief_hook.sh <client_slug>

set -euo pipefail

CLIENT_SLUG="${1:-}"
if [ -z "$CLIENT_SLUG" ]; then
  echo "Usage: bash install_morning_brief_hook.sh <client_slug>"
  exit 1
fi

SETTINGS="$HOME/.claude/settings.json"
HOOK_SCRIPT="$HOME/.sam/sam-deployments/template/scripts/morning_brief.sh"

mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo "{}" > "$SETTINGS"

python3 - "$SETTINGS" "$HOOK_SCRIPT" "$CLIENT_SLUG" <<'PY'
import json, sys
from pathlib import Path

settings_path, hook_script, slug = sys.argv[1], sys.argv[2], sys.argv[3]
data = json.loads(Path(settings_path).read_text() or "{}")

hooks = data.setdefault("hooks", {})
session_start = hooks.setdefault("SessionStart", [])

# Remove any prior SAM brief hook (idempotency)
session_start[:] = [h for h in session_start if "morning_brief.sh" not in str(h)]

session_start.append({
    "matcher": "*",
    "hooks": [{
        "type": "command",
        "command": f"bash '{hook_script}' '{slug}'"
    }]
})

Path(settings_path).write_text(json.dumps(data, indent=2))
print(f"  → SessionStart hook registered for client '{slug}'")
PY

echo ""
echo "Morning brief hook installed. Verify by opening a new Claude Code session."
echo "State file: $HOME/.sam/.brief_state"
