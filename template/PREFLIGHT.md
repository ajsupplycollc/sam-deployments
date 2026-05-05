# SAM Client Onboarding — Preflight Checklist

## The Night Before (Jereme does)
- [ ] Create Telegram bot via BotFather — save token
- [ ] Have Tailscale invite link ready (ajsupplycollc@gmail.com tailnet)
- [ ] Test AnyDesk from your machine
- [ ] Verify sam-deployments repo is pushed with latest client config
- [ ] Have client's CLAUDE.md and brand_bible ready in sam-deployments/clients/{name}/

## Text Client 1 Hour Before Call
Send them TWO download links:
1. AnyDesk: https://anydesk.com/download
2. Tailscale: https://tailscale.com/download

"Hey, download these two apps before our call. Just download and open them, that's it."

## Call Starts — First 5 Minutes (ORDER MATTERS)

### 1. AnyDesk — Get In (1 min)
- Client shares AnyDesk code on FaceTime
- Jereme connects

### 2. Tailscale — Secure the Lifeline (3 min)
**DO THIS BEFORE ANYTHING ELSE.**
If AnyDesk drops, Tailscale SSH is the fallback.

```bash
# If client already downloaded Tailscale from the link:
open -a Tailscale
# Sign in with ajsupplycollc@gmail.com (Jereme does this on their screen)

# Enable SSH — IMPORTANT: macOS CLI is NOT in PATH
sudo /Applications/Tailscale.app/Contents/MacOS/Tailscale up --ssh
```

**Verify from SAM Windows:**
```powershell
& "C:\Program Files\Tailscale\tailscale.exe" status
# Client machine should appear
ssh <username>@<tailscale-ip> "echo connected"
```

Once SSH works, AnyDesk is optional for the rest of the install.

### 3. Homebrew + Dependencies (3 min)
```bash
which brew || /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/opt/homebrew/bin/brew shellenv)"
brew install node python@3.12 git ffmpeg jq
npm install -g @anthropic-ai/claude-code
pip3 install --user edge-tts openai-whisper
```

### 4. Claude Code Auth (2 min)
- Run `claude` in Terminal
- Client types their email/password (or reads it to Jereme on FaceTime)

### 5. Run Auto-Setup Script
```bash
mkdir -p "$HOME/.sam" && cd "$HOME/.sam"
git clone https://github.com/ajsupplycollc/sam-deployments.git
cd sam-deployments
bash clients/{CLIENT_NAME}/services/auto_setup.sh
```

### 6. Shopify (if applicable) — Needs Client Login
- Navigate to {store}.myshopify.com/admin
- Settings > Apps > Develop apps > Create "SAM Agent"
- Select ALL admin API scopes > Install > Copy token

### 7. Test — Live Demo
- Client sends first voice note to their bot
- Show 2-3 quick wins on FaceTime
- End call on a high

## After the Call
- [ ] Verify Tailscale SSH works from SAM Windows
- [ ] Run full test of all workflows
- [ ] Fine-tune CLAUDE.md based on actual usage
- [ ] Day 3 and Day 7 follow-up via Telegram

## Known Gotchas (Learned the Hard Way)
1. **Tailscale CLI not in PATH on macOS** — always use `/Applications/Tailscale.app/Contents/MacOS/Tailscale`
2. **DO NOT install claude telegram plugin** — creates competing getUpdates consumer, silently eats messages. Use raw curl polling.
3. **Do Tailscale FIRST** — if AnyDesk drops mid-install, you're locked out without it
4. **macOS Tailscale installs via App Store or .app** — `brew install --cask tailscale` works but the "Add device" web flow downloads the .app directly
5. **Have client pre-download apps** — saves 5+ minutes on the call
