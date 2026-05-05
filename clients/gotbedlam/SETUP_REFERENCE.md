# Got Bedlam — Setup Reference & Troubleshooting

**This file lives in Josh's vault. Claude Code: read this when troubleshooting, verifying setup, or when anything seems broken.**

## What's Installed (Full Inventory)

### Core Stack (installed via Homebrew)
| Tool | Purpose | Verify |
|------|---------|--------|
| node | Runtime for Claude Code + MCPs | `node --version` |
| python@3.12 | Voice tools, service scripts | `python3 --version` |
| git | SAM deployments sync | `git --version` |
| ffmpeg | Audio/video processing | `ffmpeg -version` |
| jq | JSON processing | `jq --version` |

### Voice Tools (installed via pip3)
| Tool | Purpose | Verify |
|------|---------|--------|
| edge-tts | Text-to-speech (en-GB-RyanNeural) | `edge-tts --list-voices \| head -1` |
| openai-whisper | Voice transcription | `whisper --help 2>&1 \| head -1` |

### Claude Code
| Item | Detail |
|------|--------|
| Installed via | `npm install -g @anthropic-ai/claude-code` |
| Verify | `claude --version` |
| Permission mode | `--dangerously-skip-permissions` (auto-allows all tools) |
| Settings | `~/.claude/settings.json` |

### MCPs (registered in Claude Code)
| MCP | Purpose | Verify |
|-----|---------|--------|
| shopify | Shopify Admin API (GraphQL) | `claude mcp list` should show it |
| desktop-commander | Desktop control (cross-platform) | Same |
| telegram | Telegram bot plugin | Same |
| filesystem | Scoped file access to ~/.sam | Same |

### Networking
| Tool | Purpose | Verify |
|------|---------|--------|
| Tailscale | SAM remote maintenance mesh | `tailscale status` |

## File Locations

```
~/.sam/                          # SAM root
├── vault/                       # Context vault
│   ├── CLAUDE.md                # Main instructions
│   ├── brand/brand_bible.md     # Brand voice + products
│   ├── products/                # SKU data (populated post-install)
│   ├── operations/              # Ops docs
│   └── snapshots/               # Hourly state saves
│       └── LATEST.md            # Most recent snapshot
├── sam-deployments/             # Git repo (nightly pull)
│   └── clients/gotbedlam/      # This client's config
├── services/                    # Running service scripts
│   ├── watchdog.py              # Process health monitor
│   ├── health_bot.py            # /status and /restart bot
│   ├── health_alert.py          # Alert sender
│   └── hourly_snapshot.py       # State snapshot every hour
├── secrets/                     # NEVER commit these
│   ├── health_bot_token.txt     # @BedlamHealthBot token
│   └── health_bot_chat_id.txt   # Josh's Telegram chat ID
├── logs/                        # Service logs
│   ├── watchdog.log
│   ├── health_bot.log
│   └── cleanup.log
├── heartbeat.json               # Written every 30s when healthy
├── claude-code.pid              # Current process ID
├── restart.lock                 # Prevents double-restart
└── restart_history.json         # Tracks restart frequency

~/.claude/                       # Claude Code config
├── settings.json                # Hooks + permissions
└── hooks/
    ├── precompact-saver.cjs     # Saves state before compaction
    └── session-start.sh         # Runs on session start

~/Library/LaunchAgents/          # macOS auto-start services
├── com.sam.watchdog.plist       # Watchdog (KeepAlive)
├── com.sam.health-bot.plist     # Health bot (KeepAlive)
├── com.sam.hourly-snapshot.plist # Snapshot every 3600s
├── com.sam.weekly-cleanup.plist  # Cleanup Sundays 4 AM
└── com.sam.nightly-update.plist  # Git pull at 7 AM UTC
```

## Resilience Architecture

### Layer 1 — Self-Healing (automatic)
- **Watchdog** monitors PID + heartbeat file
- Dead process (PID gone) → instant restart
- Stale heartbeat (>7 min) → graceful shutdown (SIGTERM), wait 10s, then SIGKILL
- **Exponential backoff**: 3 restarts in 10 min → stop + alert Josh via health bot
- **Lock file** prevents watchdog + health bot from double-restarting

### Layer 2 — Client Recovery (Josh's phone)
- **@BedlamHealthBot** on Telegram
- `/status` — shows process state + heartbeat age
- `/restart` — bounces the Claude Code service
- Independent process — works even when main bot is dead

### Layer 3 — SAM Remote Maintenance
- Tailscale SSH for deeper issues
- Nightly git-pull keeps config fresh
- SAM (Jereme) tunnels in for config changes, updates, troubleshooting

## Troubleshooting Guide

### Homebrew Issues

**"brew: command not found" after install**
- Apple Silicon Mac: `eval "$(/opt/homebrew/bin/brew shellenv)"`
- Intel Mac: `eval "$(/usr/local/bin/brew shellenv)"`
- To check which: `uname -m` → "arm64" = Apple Silicon, "x86_64" = Intel
- Make it permanent: add the eval line to `~/.zshrc`

**Homebrew install hangs at "Downloading Command Line Tools"**
- Xcode CLT may need manual install: `xcode-select --install`
- Or skip: `HOMEBREW_NO_AUTO_UPDATE=1 brew install ...`

### npm / Node Issues

**"npm install -g: permission denied"**
- Fix: `sudo npm install -g @anthropic-ai/claude-code`
- Better fix: `mkdir ~/.npm-global && npm config set prefix '~/.npm-global'` then add `~/.npm-global/bin` to PATH

**"node: command not found" after brew install**
- Run: `brew link node`

### Claude Code Issues

**Claude Code won't authenticate**
- Verify internet: `curl -s https://api.anthropic.com` should return something
- Try: `claude logout` then `claude` again
- Check: Josh may need to accept terms at claude.ai first

**Claude Code hangs / no response**
- Check PID: `cat ~/.sam/claude-code.pid`
- Check if alive: `ps -p $(cat ~/.sam/claude-code.pid)`
- Check heartbeat: `cat ~/.sam/heartbeat.json`
- Manual restart: `kill $(cat ~/.sam/claude-code.pid) && claude --service --dangerously-skip-permissions &`

**Compaction happening (appears frozen for 3-7 min)**
- This is NORMAL. Do NOT kill the process.
- Check: PID is alive but heartbeat may be stale. Wait up to 7 min.
- After compaction: Claude Code reads LATEST.md snapshot to recover context

### Shopify MCP Issues

**"Unauthorized" or "403" from Shopify**
- Token may have expired or been revoked
- Re-create: gotbedlam.myshopify.com/admin → Settings → Apps → Develop apps → SAM Agent → rotate token
- Update: `claude mcp remove shopify` then re-add with new token

**Shopify data seems stale**
- GraphQL caches — try: add `?nocache=1` or wait 60s
- Check: the Shopify plan may rate-limit API calls

### Voice Issues

**edge-tts fails silently (no audio file created)**
- Verify: `edge-tts --text "test" --write-media /tmp/test.mp3`
- If fails: network issue (edge-tts needs internet — it uses Microsoft's cloud API)
- Fallback: send text-only reply, flag voice as temporarily unavailable

**whisper garbles transcription**
- Always use: `--condition_on_previous_text False`
- Try larger model: `--model small` instead of `--model tiny`
- If still bad: ask Josh to type or use phone's built-in speech-to-text

### Telegram Bot Issues

**Bot not responding to messages**
- Check if process is running: `ps aux | grep health_bot`
- Check token: `cat ~/.sam/secrets/health_bot_token.txt`
- Test manually: `curl "https://api.telegram.org/bot$(cat ~/.sam/secrets/health_bot_token.txt)/getMe"`
- Restart: `launchctl unload ~/Library/LaunchAgents/com.sam.health-bot.plist && launchctl load ~/Library/LaunchAgents/com.sam.health-bot.plist`

**Old voice messages replaying after restart**
- This is the stale message bug. Operational hard rule #12 covers this.
- Check timestamp on inbound messages — ignore anything >10 min old
- Weekly cleanup job deletes old voice files every Sunday

### Tailscale Issues

**"tailscale: command not found"**
- Tailscale on Mac installs as an app, not CLI: open via Spotlight
- CLI access: `/Applications/Tailscale.app/Contents/MacOS/Tailscale`

**Can't connect to SAM tailnet**
- Josh may need to re-authenticate: open Tailscale app → sign in
- Check: `tailscale status` — should show SAM machines

### Disk Space

**Running low on disk**
- Check: `df -h`
- Quick wins: `rm -rf ~/Library/Caches/Homebrew/downloads/*`
- Check whisper models: `ls -la ~/.cache/whisper/` — tiny=75MB, small=460MB
- Snapshot cleanup: only last 48 are kept automatically

### AnyDesk (for SAM remote sessions)

**AnyDesk laggy during remote session**
- Lower quality: AnyDesk → Display → Quality → "Balanced" or lower
- Close bandwidth-heavy apps on Josh's Mac during session

## Verification Checklist

Run this after install to verify everything is working:

```bash
echo "=== SAM Setup Verification ==="
echo "Node: $(node --version 2>&1)"
echo "Python: $(python3 --version 2>&1)"
echo "Git: $(git --version 2>&1)"
echo "FFmpeg: $(ffmpeg -version 2>&1 | head -1)"
echo "Claude: $(claude --version 2>&1)"
echo "Edge-TTS: $(edge-tts --help 2>&1 | head -1)"
echo "Whisper: $(whisper --help 2>&1 | head -1)"
echo "Tailscale: $(tailscale version 2>&1 | head -1)"
echo ""
echo "=== MCPs ==="
claude mcp list 2>&1
echo ""
echo "=== Services ==="
for svc in com.sam.watchdog com.sam.health-bot com.sam.hourly-snapshot com.sam.weekly-cleanup com.sam.nightly-update; do
    status=$(launchctl list | grep $svc)
    if [ -n "$status" ]; then echo "✓ $svc running"; else echo "✗ $svc NOT running"; fi
done
echo ""
echo "=== Files ==="
for f in ~/.sam/vault/CLAUDE.md ~/.sam/vault/brand/brand_bible.md ~/.sam/secrets/health_bot_token.txt ~/.sam/secrets/health_bot_chat_id.txt ~/.claude/settings.json ~/.claude/hooks/precompact-saver.cjs; do
    if [ -f "$f" ]; then echo "✓ $f"; else echo "✗ $f MISSING"; fi
done
echo ""
echo "=== Heartbeat ==="
cat ~/.sam/heartbeat.json 2>/dev/null || echo "No heartbeat yet (normal if just installed)"
echo ""
echo "=== Done ==="
```
