# Got Bedlam — Self-Install Guide

This guide is for Claude Code running on Josh Tolen's Mac. Follow every step in order. Do not skip steps. Ask Josh for credentials when needed.

## Prerequisites
- macOS
- Claude Code CLI running (you're reading this, so yes)
- Josh available to provide passwords when prompted

## Step 1 — Install Core Dependencies

Run these commands in Terminal:

```bash
# Install Homebrew if not present
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add brew to PATH (Apple Silicon Macs)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Install core tools
brew install node python@3.12 git ffmpeg jq

# Install voice tools
pip3 install --user edge-tts openai-whisper
```

## Step 2 — Clone This Repo

```bash
mkdir -p "$HOME/.sam"
cd "$HOME/.sam"
git clone https://github.com/ajsupplycollc/sam-deployments.git
cd sam-deployments
```

## Step 3 — Copy Context Files

```bash
# Copy the CLAUDE.md context bible (this is your operating instructions)
cp clients/gotbedlam/CLAUDE.md "$HOME/.claude/CLAUDE.md"

# Create vault structure
mkdir -p "$HOME/.sam/vault/brand" "$HOME/.sam/vault/products" "$HOME/.sam/vault/operations"
cp clients/gotbedlam/context/brand_bible.md "$HOME/.sam/vault/brand/"
```

## Step 4 — Register MCPs

### 4a. Shopify Admin API (THE MAIN ONE)
Ask Josh to log into gotbedlam.myshopify.com/admin in Safari. Then:
1. Go to Settings > Apps and sales channels > Develop apps
2. Click "Create an app" — name it "SAM Agent"
3. Configure Admin API scopes — SELECT ALL scopes
4. Install the app
5. Copy the Admin API access token (starts with shpat_)

Then run:
```bash
claude mcp add --transport http shopify \
  "https://gotbedlam.myshopify.com/admin/api/2025-01/graphql.json" \
  --header "X-Shopify-Access-Token: shpat_PASTE_TOKEN_HERE" \
  --header "Content-Type: application/json" \
  --scope user
```

### 4b. Desktop Commander
```bash
claude mcp add desktop-commander -- npx -y @wonderwhy-er/desktop-commander --scope user
```

### 4c. Telegram Bot
**DO NOT install the claude telegram plugin.** It creates a competing getUpdates consumer that silently eats incoming messages. Use raw curl polling against the Bot API instead.
Bot token: Ask Jereme for the @GotBedlamBot token — do NOT create a new bot.

### 4d. Filesystem
```bash
claude mcp add filesystem -- npx -y @modelcontextprotocol/server-filesystem "$HOME/.sam" --scope user
```

### 4e. Google Workspace
These are built-in claude.ai connectors. Authenticate each one in the browser when prompted:
- Gmail
- Google Calendar
- Google Drive

## Step 5 — Install Tailscale + Enable SSH

```bash
brew install --cask tailscale
```
Open Tailscale and ask Josh to log in with the invite link Jereme provides.

Then enable SSH (the CLI path on macOS is NOT in PATH by default):
```bash
sudo /Applications/Tailscale.app/Contents/MacOS/Tailscale up --ssh
```
**This is critical.** Without SSH, SAM cannot maintain this machine remotely. Do this BEFORE anything else — if AnyDesk drops, Tailscale SSH is the fallback.

## Step 6 — Set Up Nightly Auto-Update

```bash
cat > "$HOME/Library/LaunchAgents/com.sam.nightly-update.plist" << 'EOF'
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
        <string>cd $HOME/.sam/sam-deployments && git pull --ff-only 2>&1 >> $HOME/.sam/nightly.log</string>
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
```

## Step 7 — Test Everything

1. Send a test voice note to @GotBedlamBot on Telegram
2. Ask: "What are my top selling products?" (tests Shopify connection)
3. Ask: "Draft an Instagram post about BUTCHER" (tests content generation)
4. Verify voice reply comes back

## Support

If anything fails or you need help, tell your Claude Code:
"Send a message to SAM support: [describe the issue]"

This will reach Jereme's team directly on Telegram.

---

**SAM Setup Version:** 1.0
**Client:** Got Bedlam LLC / Joshua Tolen
**Created:** 2026-05-04
