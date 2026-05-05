#!/usr/bin/env python3
"""
SAM Health Alert — sends a one-shot alert to the client via the health bot.
Called by watchdog.py when restart budget is exhausted or critical failure occurs.

Usage: python health_alert.py "Alert message here"
"""

import os
import sys
import json
import urllib.request
from pathlib import Path

SAM_DIR = Path.home() / ".sam"
TOKEN_FILE = SAM_DIR / "secrets" / "health_bot_token.txt"
CHAT_ID_FILE = SAM_DIR / "secrets" / "health_bot_chat_id.txt"


def get_token():
    token = os.environ.get("TELEGRAM_HEALTH_BOT_TOKEN")
    if token:
        return token.strip()
    try:
        return TOKEN_FILE.read_text().strip()
    except Exception:
        return None


def get_chat_id():
    try:
        return CHAT_ID_FILE.read_text().strip()
    except Exception:
        return None


def send_alert(message):
    token = get_token()
    chat_id = get_chat_id()
    if not token or not chat_id:
        print("Missing token or chat_id", file=sys.stderr)
        sys.exit(1)

    url = f"https://api.telegram.org/bot{token}/sendMessage"
    data = json.dumps({"chat_id": chat_id, "text": f"⚠ SAM ALERT\n\n{message}"}).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=10)
    except Exception as e:
        print(f"Failed to send alert: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python health_alert.py 'message'", file=sys.stderr)
        sys.exit(1)
    send_alert(sys.argv[1])
