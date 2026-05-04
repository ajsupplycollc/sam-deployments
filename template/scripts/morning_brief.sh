#!/bin/bash
# Morning Brief Hook — surfaces client-facing updates from .sam-updates/
# Runs at Claude Code session start on the client's laptop.
# Reads frontmatter, filters client_facing: true, prints unsurfaced entries.
#
# State: $HOME/.sam/.brief_state  (one line: ISO date of last surfaced entry)
# Usage: bash morning_brief.sh <client_slug>

set -euo pipefail

CLIENT_SLUG="${1:-}"
if [ -z "$CLIENT_SLUG" ]; then
  exit 0  # silent no-op if not configured
fi

STACK_ROOT="$HOME/.sam"
UPDATES_DIR="$STACK_ROOT/sam-deployments/clients/$CLIENT_SLUG/.sam-updates"
STATE_FILE="$STACK_ROOT/.brief_state"

[ -d "$UPDATES_DIR" ] || exit 0

LAST_SURFACED=""
[ -f "$STATE_FILE" ] && LAST_SURFACED=$(cat "$STATE_FILE")

# Collect new entries — sort by date in frontmatter, ascending
python3 - "$UPDATES_DIR" "$LAST_SURFACED" <<'PY'
import os, sys, re, glob, io
from pathlib import Path
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

updates_dir = sys.argv[1]
last = sys.argv[2].strip()

def parse_frontmatter(path):
    text = Path(path).read_text(encoding="utf-8", errors="ignore")
    m = re.match(r"^---\s*\n(.*?)\n---\s*\n(.*)$", text, re.DOTALL)
    if not m: return None
    fm_raw, body = m.group(1), m.group(2)
    fm = {}
    for line in fm_raw.splitlines():
        if ":" in line:
            k, v = line.split(":", 1)
            fm[k.strip()] = v.strip().strip('"').strip("'")
    return fm, body

new_entries = []
for path in sorted(glob.glob(os.path.join(updates_dir, "*.md"))):
    parsed = parse_frontmatter(path)
    if not parsed: continue
    fm, body = parsed
    if fm.get("client_facing", "").lower() != "true": continue
    date = fm.get("date", "")
    if last and date <= last: continue
    new_entries.append((date, fm.get("title", os.path.basename(path)), body.strip()))

if not new_entries:
    sys.exit(0)

print("════════════════════════════════════════════════════════════════")
print("  Overnight from SAM")
print("════════════════════════════════════════════════════════════════")
print()
for date, title, body in new_entries:
    print(f"  [{date}] {title}")
    print()
    for line in body.splitlines():
        print(f"    {line}")
    print()
print("════════════════════════════════════════════════════════════════")

# Write latest date to state
latest = max(e[0] for e in new_entries)
state_path = os.path.join(os.path.expanduser("~"), ".sam", ".brief_state")
os.makedirs(os.path.dirname(state_path), exist_ok=True)
Path(state_path).write_text(latest)
PY
