#!/usr/bin/env python3
"""
SAM Watchdog — monitors Claude Code process health and auto-recovers.

Checks:
1. PID file — is the main process alive?
2. Heartbeat file — has it updated within the grace period?

Recovery:
- Dead process (PID gone) → immediate restart
- Stale heartbeat (>7 min) → graceful shutdown, then force kill after 10s
- Exponential backoff: 3 restarts in 10 min → stop and alert via health bot

Runs as a separate launchd service. Does NOT touch Claude Code config,
memory, or session state — only reads heartbeat and checks PID.
"""

import os
import sys
import time
import signal
import subprocess
import json
from pathlib import Path
from datetime import datetime, timedelta

SAM_DIR = Path.home() / ".sam"
HEARTBEAT_FILE = SAM_DIR / "heartbeat.json"
PID_FILE = SAM_DIR / "claude-code.pid"
LOCK_FILE = SAM_DIR / "restart.lock"
LOG_FILE = SAM_DIR / "watchdog.log"
RESTART_HISTORY_FILE = SAM_DIR / "restart_history.json"

HEARTBEAT_GRACE_SECONDS = 420  # 7 minutes
CHECK_INTERVAL_SECONDS = 30
GRACEFUL_SHUTDOWN_WAIT = 10
MAX_RESTARTS_IN_WINDOW = 3
RESTART_WINDOW_SECONDS = 600  # 10 minutes

HEALTH_BOT_ALERT_SCRIPT = SAM_DIR / "services" / "health_alert.py"


def log(msg):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{ts}] {msg}"
    print(line)
    try:
        with open(LOG_FILE, "a") as f:
            f.write(line + "\n")
    except Exception:
        pass


def read_pid():
    try:
        return int(PID_FILE.read_text().strip())
    except Exception:
        return None


def is_process_alive(pid):
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def read_heartbeat_age():
    try:
        data = json.loads(HEARTBEAT_FILE.read_text())
        last_beat = datetime.fromisoformat(data["timestamp"])
        return (datetime.now() - last_beat).total_seconds()
    except Exception:
        return None


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


def load_restart_history():
    try:
        return json.loads(RESTART_HISTORY_FILE.read_text())
    except Exception:
        return []


def save_restart_history(history):
    try:
        RESTART_HISTORY_FILE.write_text(json.dumps(history))
    except Exception:
        pass


def check_restart_budget():
    history = load_restart_history()
    cutoff = time.time() - RESTART_WINDOW_SECONDS
    recent = [t for t in history if t > cutoff]
    save_restart_history(recent)
    return len(recent) < MAX_RESTARTS_IN_WINDOW


def record_restart():
    history = load_restart_history()
    history.append(time.time())
    save_restart_history(history)


def send_alert(message):
    log(f"ALERT: {message}")
    try:
        if HEALTH_BOT_ALERT_SCRIPT.exists():
            subprocess.Popen(
                [sys.executable, str(HEALTH_BOT_ALERT_SCRIPT), message],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    except Exception as e:
        log(f"Failed to send alert: {e}")


def graceful_stop(pid):
    log(f"Sending SIGTERM to PID {pid}")
    try:
        os.kill(pid, signal.SIGTERM)
    except OSError:
        return
    for _ in range(GRACEFUL_SHUTDOWN_WAIT):
        time.sleep(1)
        if not is_process_alive(pid):
            log("Process stopped gracefully")
            return
    log(f"Process still alive after {GRACEFUL_SHUTDOWN_WAIT}s, sending SIGKILL")
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass


def start_claude_code():
    if not acquire_lock():
        log("Lock held by another process, skipping restart")
        return False
    try:
        if not check_restart_budget():
            msg = "Restart budget exhausted (3 restarts in 10 min). SAM needs to look at this."
            send_alert(msg)
            return False

        log("Starting Claude Code service...")
        proc = subprocess.Popen(
            ["claude", "--service", "--dangerously-skip-permissions"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        PID_FILE.write_text(str(proc.pid))
        record_restart()
        log(f"Claude Code started with PID {proc.pid}")
        return True
    except Exception as e:
        log(f"Failed to start Claude Code: {e}")
        send_alert(f"Failed to start Claude Code: {e}")
        return False
    finally:
        release_lock()


def restart_claude_code(reason):
    pid = read_pid()
    if is_process_alive(pid):
        graceful_stop(pid)
    log(f"Restarting — reason: {reason}")
    return start_claude_code()


def main():
    log("Watchdog starting")
    SAM_DIR.mkdir(parents=True, exist_ok=True)

    while True:
        try:
            pid = read_pid()
            alive = is_process_alive(pid)

            if not alive:
                log("Process is dead")
                restart_claude_code("process dead (PID gone)")
            else:
                heartbeat_age = read_heartbeat_age()
                if heartbeat_age is None:
                    log("No heartbeat file found — process may be initializing")
                elif heartbeat_age > HEARTBEAT_GRACE_SECONDS:
                    log(f"Heartbeat stale ({heartbeat_age:.0f}s old, grace={HEARTBEAT_GRACE_SECONDS}s)")
                    restart_claude_code(f"heartbeat stale ({heartbeat_age:.0f}s)")

        except Exception as e:
            log(f"Watchdog error: {e}")

        time.sleep(CHECK_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
