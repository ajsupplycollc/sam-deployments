#!/bin/bash
# Fix Telegram bot receiving on Josh's Mac
# Run via Tailscale SSH or have Josh paste in Terminal
# This removes the competing telegram plugin and cleans up residual processes

echo ">>> Fixing Telegram bot..."

# 1. Remove the telegram plugin (the root cause)
claude plugin remove telegram 2>/dev/null && echo "  ✓ Telegram plugin removed" || echo "  ℹ No telegram plugin found (already clean)"

# 2. Kill any residual telegram/polling processes
pkill -f telegram_mcp 2>/dev/null
pkill -f telegram_poller 2>/dev/null
echo "  ✓ Residual processes cleaned"

# 3. Remove any leftover mcp.json telegram entries
if [ -f "$HOME/.claude/mcp.json" ]; then
    python3 -c "
import json
with open('$HOME/.claude/mcp.json') as f:
    d = json.load(f)
if 'mcpServers' in d and 'telegram' in d['mcpServers']:
    del d['mcpServers']['telegram']
    with open('$HOME/.claude/mcp.json', 'w') as f:
        json.dump(d, f, indent=2)
    print('  ✓ Removed telegram from mcp.json')
else:
    print('  ℹ No telegram in mcp.json')
" 2>/dev/null || echo "  ℹ No mcp.json to clean"
fi

# 4. Verify bot is clean (no 409 conflict, no competing consumers)
echo ""
echo ">>> Verifying bot status..."
RESULT=$(curl -s "https://api.telegram.org/bot8124709993:AAF7094-hQlb0dmQ5Ie-hAAW4fa5QMRpKDc/getUpdates?timeout=1")
if echo "$RESULT" | grep -q '"ok":true'; then
    echo "  ✓ GotBedlamBot is clean — no competing consumers"
else
    echo "  ⚠ Bot returned unexpected response: $RESULT"
fi

echo ""
echo ">>> Telegram fix complete. Start claude and paste the operating prompt."
