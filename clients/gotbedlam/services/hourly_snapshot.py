#!/usr/bin/env python3
"""
SAM Hourly Snapshot — saves system state every hour via launchd.

Captures:
- Active Claude Code session info (if running)
- Git state of sam-deployments
- Vault directory listing
- Last heartbeat status
- Pending Telegram messages (count only)

Writes to ~/.sam/vault/snapshots/ with timestamped filenames.
LATEST.md is always a copy of the most recent snapshot.
"""

import json
import subprocess
from pathlib import Path
from datetime import datetime

SAM_DIR = Path.home() / ".sam"
VAULT_DIR = SAM_DIR / "vault"
SNAPSHOTS_DIR = VAULT_DIR / "snapshots"
HEARTBEAT_FILE = SAM_DIR / "heartbeat.json"
PID_FILE = SAM_DIR / "claude-code.pid"
DEPLOY_DIR = SAM_DIR / "sam-deployments"


def run_cmd(cmd, cwd=None):
    try:
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=10, cwd=cwd
        )
        return result.stdout.strip() if result.returncode == 0 else f"(error: {result.stderr.strip()})"
    except Exception as e:
        return f"(failed: {e})"


def get_process_status():
    try:
        pid = int(PID_FILE.read_text().strip())
        import os
        os.kill(pid, 0)
        return f"Running (PID {pid})"
    except Exception:
        return "Not running"


def get_heartbeat():
    try:
        data = json.loads(HEARTBEAT_FILE.read_text())
        ts = data.get("timestamp", "unknown")
        age = (datetime.now() - datetime.fromisoformat(ts)).total_seconds()
        return f"{ts} ({age:.0f}s ago)"
    except Exception:
        return "No heartbeat data"


def get_git_state():
    if not DEPLOY_DIR.exists():
        return "sam-deployments not cloned"
    branch = run_cmd(["git", "branch", "--show-current"], cwd=str(DEPLOY_DIR))
    commit = run_cmd(["git", "log", "-1", "--format=%h %s"], cwd=str(DEPLOY_DIR))
    status = run_cmd(["git", "status", "--short"], cwd=str(DEPLOY_DIR))
    return f"Branch: {branch}\nLast commit: {commit}\nStatus: {status or '(clean)'}"


def get_vault_listing():
    if not VAULT_DIR.exists():
        return "Vault not initialized"
    files = []
    for p in sorted(VAULT_DIR.rglob("*")):
        if p.is_file() and "snapshots" not in str(p):
            rel = p.relative_to(VAULT_DIR)
            files.append(str(rel))
    return "\n".join(files[:30]) if files else "(empty)"


def main():
    SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)

    now = datetime.now()
    ts = now.strftime("%Y-%m-%dT%H-%M-%S")

    snapshot = f"""# SAM Snapshot — {now.strftime("%Y-%m-%d %H:%M:%S ET")}

## Claude Code
{get_process_status()}

## Heartbeat
{get_heartbeat()}

## Git State
{get_git_state()}

## Vault Contents
{get_vault_listing()}
"""

    snapshot_file = SNAPSHOTS_DIR / f"hourly-{ts}.md"
    snapshot_file.write_text(snapshot)

    latest_file = SNAPSHOTS_DIR / "LATEST.md"
    latest_file.write_text(snapshot)

    # Keep only last 48 snapshots (2 days)
    snapshots = sorted(SNAPSHOTS_DIR.glob("hourly-*.md"))
    for old in snapshots[:-48]:
        old.unlink()

    print(f"Snapshot saved: {snapshot_file.name}")


if __name__ == "__main__":
    main()
