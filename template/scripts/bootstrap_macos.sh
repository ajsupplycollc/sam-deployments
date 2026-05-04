#!/bin/bash
# SAM Deployment Bootstrap — macOS
# Run during remote-desktop session with Jereme. Requires sudo for Homebrew + launchd setup.
# Usage: bash bootstrap_macos.sh <client_slug>
#   e.g. bash bootstrap_macos.sh gotbedlam

set -euo pipefail

CLIENT_SLUG="${1:-}"
if [ -z "$CLIENT_SLUG" ]; then
  echo "Usage: bash bootstrap_macos.sh <client_slug>"
  exit 1
fi

STACK_ROOT="$HOME/.sam"
REPO_URL="git@github.com:StrangeAdvancedMarketing/sam-deployments.git"
CLIENT_DIR="$STACK_ROOT/clients/$CLIENT_SLUG"

echo "════════════════════════════════════════════════════════════════"
echo "  SAM Stack Bootstrap — macOS"
echo "  Client: $CLIENT_SLUG"
echo "  Target: $STACK_ROOT"
echo "════════════════════════════════════════════════════════════════"

# ---------- 1. Prereqs via Homebrew ----------
if ! command -v brew >/dev/null 2>&1; then
  echo "[1/10] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)" 2>/dev/null || eval "$(/usr/local/bin/brew shellenv)"
else
  echo "[1/10] Homebrew: already installed"
fi

echo "[2/10] Installing core deps (node, python, git, ffmpeg, jq)..."
brew install node python@3.12 git ffmpeg jq

# ---------- 2. Claude Code CLI ----------
echo "[3/10] Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# ---------- 3. Voice I/O deps ----------
echo "[4/10] Installing edge-tts + whisper..."
pip3 install --user edge-tts openai-whisper

# ---------- 4. Clone sam-deployments (sparse) ----------
echo "[5/10] Cloning sam-deployments (sparse-checkout on $CLIENT_SLUG)..."
mkdir -p "$STACK_ROOT"
cd "$STACK_ROOT"
if [ ! -d "sam-deployments/.git" ]; then
  git clone --filter=blob:none --sparse "$REPO_URL" sam-deployments
  cd sam-deployments
  git sparse-checkout init --cone
  git sparse-checkout set "clients/$CLIENT_SLUG" "template"
else
  cd sam-deployments
  git pull --ff-only
fi

# ---------- 5. Tailscale ----------
if ! command -v tailscale >/dev/null 2>&1; then
  echo "[6/10] Installing Tailscale..."
  brew install --cask tailscale
  echo "  → Open Tailscale from Applications and sign in. SAM will invite you to the tailnet."
else
  echo "[6/10] Tailscale: already installed"
fi

# ---------- 6. Obsidian ----------
if [ ! -d "/Applications/Obsidian.app" ]; then
  echo "[7/10] Installing Obsidian..."
  brew install --cask obsidian
else
  echo "[7/10] Obsidian: already installed"
fi

# ---------- 7. MCP server installs (deferred until creds entered) ----------
echo "[8/10] MCP install deferred → runs after credentials.env is populated."
echo "  → Companion script: $STACK_ROOT/sam-deployments/template/scripts/install_mcps.sh"
echo "  → Will register: shopify, postiz, telegram, filesystem (client-scoped)."

# ---------- 8. Nightly git-pull via launchd ----------
echo "[9/10] Setting up nightly git-pull (3 AM ET = 7 AM UTC)..."
PLIST_PATH="$HOME/Library/LaunchAgents/com.sam.nightly-update.plist"
cat > "$PLIST_PATH" <<EOF
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
        <string>cd $STACK_ROOT/sam-deployments && git pull --ff-only 2>&1 >> $STACK_ROOT/nightly.log</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$STACK_ROOT/nightly.log</string>
    <key>StandardErrorPath</key>
    <string>$STACK_ROOT/nightly.log</string>
</dict>
</plist>
EOF
launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

# ---------- 9. Interactive credential prompts ----------
echo ""
echo "════════════════════════════════════════════════════════════════"
echo "  [10/10] Live credential setup — Jereme drives this section"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "  The remaining items are handled live with the client watching:"
echo ""
echo "    1. Telegram bot — create via BotFather OR use SAM-provisioned bot"
echo "    2. Anthropic API key — client logs in at console.anthropic.com"
echo "    3. Google Workspace OAuth — via gog.exe auth add <email>"
echo "    4. Shopify Admin API token — client's store → Apps → Develop apps → create custom app → API scopes → generate token"
echo "    5. Postiz — client signs up at postiz.com, connects socials, copies API key"
echo "    6. ChatGPT data import — client exports from chatgpt.com → we pipe into Obsidian vault"
echo ""
echo "  Once credentials are captured, write them to:"
echo "    $STACK_ROOT/credentials.env"
echo "  Then run:"
echo "    bash $STACK_ROOT/sam-deployments/template/scripts/install_mcps.sh"
echo ""
echo "  Stack location: $STACK_ROOT"
echo "  Client folder: $CLIENT_DIR"
echo "  Logs: $STACK_ROOT/nightly.log"
echo ""
echo "  Ready for fine-tuning."
echo "════════════════════════════════════════════════════════════════"
