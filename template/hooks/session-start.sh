#!/bin/bash
# SAM Client — Session start hook
# Provides boot context on every new session

echo "SessionStart:startup hook success: Session start: $(TZ='America/New_York' date '+%Y-%m-%d %I:%M %p %Z')"
echo "Disk free: $(df -h ~ 2>/dev/null | tail -1 | awk '{print $4}')"

# Check for snapshot from prior compaction
SNAPSHOT="$HOME/.sam/snapshots/LATEST.md"
if [ -f "$SNAPSHOT" ]; then
  echo "Recent compaction snapshot found — check ~/.sam/snapshots/LATEST.md"
fi

# Check for HANDOFF
HANDOFF="$HOME/.sam/HANDOFF.md"
if [ -f "$HANDOFF" ]; then
  echo "HANDOFF.md found — read it first"
fi
