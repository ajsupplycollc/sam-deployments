#!/bin/bash
# SAM Auto-Setup for Got Bedlam
# Run this AFTER Claude Code is authenticated (Step 4 complete)
# Claude Code pastes this single script and it handles Steps 6-9
# Steps 5 (Shopify) and 8 (Tailscale) still need human interaction

echo "═══ SAM AUTO-SETUP STARTING ═══"

# Step 0 — Tailscale SSH (do this FIRST — if AnyDesk drops, we still have access)
echo ""
echo ">>> STEP 0: Enabling Tailscale SSH..."
TS_CLI="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS_CLI" ]; then
    sudo "$TS_CLI" up --ssh && echo "  ✓ Tailscale SSH enabled" || echo "  ⚠ Tailscale SSH failed — run manually: sudo $TS_CLI up --ssh"
elif command -v tailscale &>/dev/null; then
    sudo tailscale up --ssh && echo "  ✓ Tailscale SSH enabled" || echo "  ⚠ Tailscale SSH failed"
else
    echo "  ⚠ Tailscale not found — install first: brew install --cask tailscale"
fi

# Step 6 — Register MCPs (|| true so one failure doesn't kill the script)
echo ""
echo ">>> STEP 6: Registering MCPs..."
claude mcp add desktop-commander -- npx -y @wonderwhy-er/desktop-commander --scope user && echo "  ✓ Desktop Commander" || echo "  ⚠ Desktop Commander failed — will retry manually"
# NOTE: Do NOT install claude telegram plugin here. It creates a competing
# getUpdates consumer that silently eats all incoming messages. Client's
# Claude Code should use raw curl to poll the Bot API instead.
echo "  ℹ Telegram: use raw curl polling (no plugin — avoids competing consumers)"
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem "$HOME/.sam" --scope user && echo "  ✓ Filesystem" || echo "  ⚠ Filesystem failed — will retry manually"
echo ">>> MCPs done."

# Step 7 — Clone SAM config + vault
echo ""
echo ">>> STEP 7: Cloning SAM config..."
mkdir -p "$HOME/.sam"
cd "$HOME/.sam"
if [ ! -d "sam-deployments" ]; then
    git clone --filter=blob:none --sparse https://github.com/ajsupplycollc/sam-deployments.git
    cd sam-deployments
    git sparse-checkout init --cone
    git sparse-checkout set "clients/gotbedlam" "template"
else
    cd sam-deployments
    git pull --ff-only
fi
echo "  ✓ SAM deployments cloned"

mkdir -p "$HOME/.sam/vault/brand" "$HOME/.sam/vault/products" "$HOME/.sam/vault/operations"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/CLAUDE.md" "$HOME/.sam/vault/"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/CLAUDE.md" "$HOME/.claude/CLAUDE.md"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/SETUP_REFERENCE.md" "$HOME/.sam/vault/"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/context/brand_bible.md" "$HOME/.sam/vault/brand/"
echo "  ✓ Vault initialized (CLAUDE.md copied to both ~/.sam/vault/ and ~/.claude/)"

# Step 9 — Hooks + resilience
echo ""
echo ">>> STEP 9: Installing hooks and resilience stack..."
mkdir -p "$HOME/.claude/hooks" "$HOME/.sam/services" "$HOME/.sam/logs" "$HOME/.sam/secrets" "$HOME/.sam/vault/snapshots"

cp "$HOME/.sam/sam-deployments/template/hooks/precompact-saver.cjs" "$HOME/.claude/hooks/" 2>/dev/null || echo "  ⚠ precompact-saver.cjs not found in template — will set up manually"
cp "$HOME/.sam/sam-deployments/template/hooks/session-start.sh" "$HOME/.claude/hooks/" 2>/dev/null || echo "  ⚠ session-start.sh not found in template — will set up manually"
chmod +x "$HOME/.claude/hooks/session-start.sh" 2>/dev/null
echo "  ✓ Hooks installed"

cp "$HOME/.sam/sam-deployments/clients/gotbedlam/services/watchdog.py" "$HOME/.sam/services/"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/services/health_bot.py" "$HOME/.sam/services/"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/services/health_alert.py" "$HOME/.sam/services/"
cp "$HOME/.sam/sam-deployments/clients/gotbedlam/services/hourly_snapshot.py" "$HOME/.sam/services/"
echo "  ✓ Service scripts copied"

# Health bot token — prompt instead of hardcoding
if [ ! -f "$HOME/.sam/secrets/health_bot_token.txt" ]; then
    echo ""
    echo "  ⚠ Health bot token needed. Paste this in a separate terminal:"
    echo "    echo 'YOUR_HEALTH_BOT_TOKEN' > \$HOME/.sam/secrets/health_bot_token.txt"
    echo "  (Jereme has the token — ask him)"
fi

# Health bot chat ID check
if [ ! -f "$HOME/.sam/secrets/health_bot_chat_id.txt" ]; then
    echo ""
    echo "  ⚠ Health bot chat_id needed after Josh /starts @BedlamHealthBot."
    echo "    Save it: echo 'JOSH_CHAT_ID' > \$HOME/.sam/secrets/health_bot_chat_id.txt"
fi

# Install launchd plists
for plist in com.sam.watchdog com.sam.health-bot com.sam.hourly-snapshot com.sam.weekly-cleanup; do
    src="$HOME/.sam/sam-deployments/clients/gotbedlam/services/launchd/$plist.plist"
    if [ -f "$src" ]; then
        cp "$src" "$HOME/Library/LaunchAgents/"
        sed -i '' "s|~/|$HOME/|g" "$HOME/Library/LaunchAgents/$plist.plist"
        launchctl load "$HOME/Library/LaunchAgents/$plist.plist"
        echo "  ✓ $plist loaded"
    else
        echo "  ⚠ $plist.plist not found — skipping"
    fi
done

# Nightly auto-update (inline — $HOME expands at runtime via bash -c)
cat > "$HOME/Library/LaunchAgents/com.sam.nightly-update.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.sam.nightly-update</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd $HOME/.sam/sam-deployments &amp;&amp; git pull --ff-only 2&gt;&amp;1 &gt;&gt; $HOME/.sam/nightly.log</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>7</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
</dict>
</plist>
EOF
launchctl load "$HOME/Library/LaunchAgents/com.sam.nightly-update.plist"
echo "  ✓ Nightly update loaded"

# Claude Code settings
mkdir -p "$HOME/.claude"
cat > "$HOME/.claude/settings.json" << 'SETTINGS'
{
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "PreCompact": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "node $HOME/.claude/hooks/precompact-saver.cjs"
          }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash $HOME/.claude/hooks/session-start.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS
echo "  ✓ Claude Code settings configured"

echo ""
echo "═══ SAM AUTO-SETUP COMPLETE ═══"
echo ""
echo "STILL NEEDS HUMAN:"
echo "  → Step 5: Create Shopify app + paste token"
echo "  → Health bot token: echo 'TOKEN' > ~/.sam/secrets/health_bot_token.txt"
echo "  → Josh's chat_id: have Josh /start @BedlamHealthBot, then save his ID"
echo ""
echo "VERIFY:"
echo "  → Tailscale SSH: from SAM Windows, run: ssh joshuatolen@<tailscale-ip>"
echo "  → Telegram bot: send a test message to the bot"
