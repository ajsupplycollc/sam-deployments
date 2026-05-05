#!/usr/bin/env python3
"""
SAM Health Bot — lightweight Telegram bot for client-initiated recovery.

Commands:
  /status  — Check if Claude Code service is running
  /restart — Bounce the Claude Code service
  /help    — Show available commands

Runs as an independent launchd service. Shares lock file with watchdog
to prevent simultaneous restart attempts.

Requires: TELEGRAM_HEALTH_BOT_TOKEN environment variable or token file.
"""

import os
import sys
import json
import signal
import subprocess
import time
import urllib.request
import urllib.parse
from pathlib import Path
from datetime import datetime

SAM_DIR = Path.home() / ".sam"
PID_FILE = SAM_DIR / "claude-code.pid"
HEARTBEAT_FILE = SAM_DIR / "heartbeat.json"
LOCK_FILE = SAM_DIR / "restart.lock"
LOG_FILE = SAM_DIR / "health_bot.log"
TOKEN_FILE = SAM_DIR / "secrets" / "health_bot_token.txt"
OFFSET_FILE = SAM_DIR / "health_bot_offset.txt"
CHAT_ID_FILE = SAM_DIR / "secrets" / "health_bot_chat_id.txt"
SAM_CHAT_ID = "6583705239"  # Jereme (SAM) always has access

POLL_TIMEOUT = 30


def is_authorized(chat_id):
    allowed = {SAM_CHAT_ID}
    try:
        client_id = CHAT_ID_FILE.read_text().strip()
        if client_id:
            allowed.add(client_id)
    except Exception:
        pass
    return str(chat_id) in allowed


def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass


def get_token():
    token = os.environ.get("TELEGRAM_HEALTH_BOT_TOKEN")
    if token:
        return token.strip()
    try:
        return TOKEN_FILE.read_text().strip()
    except Exception:
        log("No bot token found. Set TELEGRAM_HEALTH_BOT_TOKEN or create token file.")
        sys.exit(1)


def api_call(token, method, params=None):
    url = f"https://api.telegram.org/bot{token}/{method}"
    if params:
        data = json.dumps(params).encode()
        req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    else:
        req = urllib.request.Request(url)
    try:
        resp = urllib.request.urlopen(req, timeout=POLL_TIMEOUT + 10)
        return json.loads(resp.read().decode())
    except Exception as e:
        log(f"API error ({method}): {e}")
        return None


def send_message(token, chat_id, text):
    api_call(token, "sendMessage", {"chat_id": chat_id, "text": text})


def is_process_alive(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def read_pid():
    try:
        return int(PID_FILE.read_text().strip())
    except Exception:
        return None


def get_status():
    pid = read_pid()
    alive = is_process_alive(pid)

    heartbeat_info = ""
    try:
        data = json.loads(HEARTBEAT_FILE.read_text())
        last_beat = datetime.fromisoformat(data["timestamp"])
        age = (datetime.now() - last_beat).total_seconds()
        if age < 60:
            heartbeat_info = f"Heartbeat: {age:.0f}s ago (healthy)"
        elif age < 420:
            heartbeat_info = f"Heartbeat: {age:.0f}s ago (may be compacting)"
        else:
            heartbeat_info = f"Heartbeat: {age:.0f}s ago (STALE)"
    except Exception:
        heartbeat_info = "Heartbeat: no data"

    if alive:
        return f"Claude Code is RUNNING (PID {pid})\n{heartbeat_info}"
    else:
        return f"Claude Code is DOWN\n{heartbeat_info}"


def acquire_lock():
    if LOCK_FILE.exists():
        try:
            lock_age = time.time() - LOCK_FILE.stat().st_mtime
            if lock_age > 60:
                LOCK_FILE.unlink()
            else:
                return False
        except Exception:
            return False
    try:
        LOCK_FILE.write_text(str(os.getpid()))
        return True
    except Exception:
        return False


def release_lock():
    try:
        LOCK_FILE.unlink(missing_ok=True)
    except Exception:
        pass


def do_restart():
    if not acquire_lock():
        return "Another restart is already in progress. Wait a moment and try again."
    try:
        pid = read_pid()
        if is_process_alive(pid):
            log(f"Health bot restart: sending SIGTERM to {pid}")
            try:
                os.kill(pid, signal.SIGTERM)
            except OSError:
                pass
            for _ in range(10):
                time.sleep(1)
                if not is_process_alive(pid):
                    break
            if is_process_alive(pid):
                try:
                    os.kill(pid, signal.SIGKILL)
                except OSError:
                    pass

        log("Health bot restart: starting Claude Code")
        proc = subprocess.Popen(
            ["claude", "--service", "--dangerously-skip-permissions"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        PID_FILE.write_text(str(proc.pid))
        log(f"Restarted with PID {proc.pid}")
        return f"Claude Code restarted (PID {proc.pid}). Give it 15-30 seconds to initialize."
    except Exception as e:
        log(f"Restart failed: {e}")
        return f"Restart failed: {e}\nSAM support may need to look at this."
    finally:
        release_lock()


def get_offset():
    try:
        return int(OFFSET_FILE.read_text().strip())
    except Exception:
        return 0


def save_offset(offset):
    try:
        OFFSET_FILE.write_text(str(offset))
    except Exception:
        pass


def main():
    log("Health bot starting")
    SAM_DIR.mkdir(parents=True, exist_ok=True)
    (SAM_DIR / "secrets").mkdir(parents=True, exist_ok=True)

    token = get_token()
    me = api_call(token, "getMe")
    if me and me.get("ok"):
        log(f"Bot: @{me['result'].get('username', 'unknown')}")
    else:
        log("Failed to connect to Telegram")
        sys.exit(1)

    offset = get_offset()

    while True:
        try:
            result = api_call(token, "getUpdates", {
                "offset": offset,
                "timeout": POLL_TIMEOUT,
                "allowed_updates": ["message"],
            })
            if not result or not result.get("ok"):
                time.sleep(5)
                continue

            for update in result.get("result", []):
                offset = update["update_id"] + 1
                save_offset(offset)

                msg = update.get("message", {})
                text = msg.get("text", "").strip()
                chat_id = msg.get("chat", {}).get("id")
                if not chat_id or not text:
                    continue

                cmd = text.lower().split()[0] if text else ""

                if not is_authorized(chat_id):
                    send_message(token, chat_id, "Unauthorized. Contact SAM support.")
                    continue

                if cmd == "/status":
                    send_message(token, chat_id, get_status())
                elif cmd == "/restart":
                    send_message(token, chat_id, "Restarting Claude Code...")
                    reply = do_restart()
                    send_message(token, chat_id, reply)
                elif cmd in ("/help", "/start"):
                    send_message(token, chat_id,
                        "SAM Health Bot\n\n"
                        "/status — Check if Claude Code is running\n"
                        "/restart — Restart Claude Code service\n"
                        "/help — Show this message"
                    )
                else:
                    send_message(token, chat_id,
                        "I only handle service health. Use /status or /restart.\n"
                        "For everything else, message your main bot."
                    )

        except KeyboardInterrupt:
            log("Health bot stopped")
            break
        except Exception as e:
            log(f"Error: {e}")
            time.sleep(5)


if __name__ == "__main__":
    main()
