#!/usr/bin/env python3
"""The Grass Lady Telegram Bot — standalone with voice responses."""

import json
import os
import re
import subprocess
import sys
import time
import tempfile
import threading
import urllib.request
import urllib.error

# === CONFIGURE THESE ===
BOT_TOKEN = "8491268226:AAHG0iHYonR6IymXlFLq0_sWVLhhOLRP_8U"
ALLOWED_USERS = []  # Add Darleen's Telegram user ID
VOICE = "en-GB-RyanNeural"

# === Paths (Windows) ===
CLAUDE_PATH = os.path.expanduser("~\\.claude\\local\\claude.exe")
WHISPER_PATH = "whisper"
EDGE_TTS = "edge-tts"
API_BASE = "https://api.telegram.org/bot" + BOT_TOKEN
OFFSET_FILE = os.path.expanduser("~\\.sam\\telegram_bot_offset")
WORK_DIR = os.path.expanduser("~\\.sam\\sam-deployments\\clients\\the-grass-lady")
BOOT_TIME = int(time.time())
LOG_FILE = os.path.expanduser("~\\.sam\\logs\\telegram_bot.log")


def log(msg):
    """Log to file and stdout."""
    line = msg
    print(line, flush=True)
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    except Exception:
        pass


def api_call(method, data=None):
    url = API_BASE + "/" + method
    if data:
        payload = json.dumps(data).encode()
        req = urllib.request.Request(
            url, data=payload, headers={"Content-Type": "application/json"}
        )
    else:
        req = urllib.request.Request(url)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode() if e.fp else ""
        log("API error " + str(e.code) + ": " + body)
        return None
    except Exception as e:
        log("Request error: " + str(e))
        return None


def send_multipart(method, fields, files):
    boundary = "----BotBoundary" + str(int(time.time()))
    body = b""
    for key, val in fields.items():
        body += ("--" + boundary + "\r\n").encode()
        body += ('Content-Disposition: form-data; name="' + key + '"\r\n\r\n').encode()
        body += (str(val) + "\r\n").encode()
    for key, (filename, filedata, ctype) in files.items():
        body += ("--" + boundary + "\r\n").encode()
        body += ('Content-Disposition: form-data; name="' + key + '"; filename="' + filename + '"\r\n').encode()
        body += ("Content-Type: " + ctype + "\r\n\r\n").encode()
        body += filedata + b"\r\n"
    body += ("--" + boundary + "--\r\n").encode()
    url = API_BASE + "/" + method
    req = urllib.request.Request(url, data=body)
    req.add_header("Content-Type", "multipart/form-data; boundary=" + boundary)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())
    except Exception as e:
        log("Multipart error: " + str(e))
        return None


def send_message(chat_id, text):
    for i in range(0, len(text), 4000):
        chunk = text[i:i + 4000]
        api_call("sendMessage", {"chat_id": chat_id, "text": chunk})


def send_voice(chat_id, voice_path):
    with open(voice_path, "rb") as f:
        data = f.read()
    send_multipart("sendVoice", {"chat_id": str(chat_id)},
                   {"voice": ("voice.mp3", data, "audio/mpeg")})


def send_typing(chat_id):
    api_call("sendChatAction", {"chat_id": chat_id, "action": "typing"})


def typing_loop(chat_id, stop_event):
    while not stop_event.is_set():
        send_typing(chat_id)
        stop_event.wait(4)


def get_updates(offset):
    return api_call("getUpdates", {"offset": offset, "timeout": 30})


def load_offset():
    try:
        with open(OFFSET_FILE) as f:
            return int(f.read().strip())
    except Exception:
        return 0


def save_offset(offset):
    try:
        os.makedirs(os.path.dirname(OFFSET_FILE), exist_ok=True)
        with open(OFFSET_FILE, "w") as f:
            f.write(str(offset))
    except Exception:
        pass


def strip_markdown(text):
    text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
    text = re.sub(r'\*(.+?)\*', r'\1', text)
    text = re.sub(r'`(.+?)`', r'\1', text)
    text = re.sub(r'#{1,6}\s+', '', text)
    text = re.sub(r'^\s*[-*]\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'^\s*\d+\.\s+', '', text, flags=re.MULTILINE)
    text = re.sub(r'\[(.+?)\]\(.+?\)', r'\1', text)
    return text.strip()


def generate_voice(text):
    try:
        voice_text = strip_markdown(text)[:2000]
        tmp = tempfile.NamedTemporaryFile(suffix=".mp3", delete=False, dir=tempfile.gettempdir())
        tmp.close()
        result = subprocess.run(
            [EDGE_TTS, "--voice", VOICE, "--rate=+20%", "--text", voice_text,
             "--write-media", tmp.name],
            capture_output=True, text=True, timeout=30,
        )
        if result.returncode == 0 and os.path.exists(tmp.name) and os.path.getsize(tmp.name) > 0:
            return tmp.name
        log("TTS failed: " + result.stderr[:200])
        os.unlink(tmp.name)
        return None
    except Exception as e:
        log("TTS error: " + str(e))
        return None


def download_telegram_file(file_id):
    result = api_call("getFile", {"file_id": file_id})
    if not result or not result.get("ok"):
        return None
    file_path = result["result"]["file_path"]
    url = "https://api.telegram.org/file/bot" + BOT_TOKEN + "/" + file_path
    ext = os.path.splitext(file_path)[1] or ".ogg"
    tmp = tempfile.NamedTemporaryFile(suffix=ext, delete=False, dir=tempfile.gettempdir())
    tmp.close()
    try:
        urllib.request.urlretrieve(url, tmp.name)
        return tmp.name
    except Exception as e:
        log("Download error: " + str(e))
        return None


def transcribe_voice(audio_path):
    try:
        out_dir = tempfile.mkdtemp(dir=tempfile.gettempdir(), prefix="whisper_")
        result = subprocess.run(
            [WHISPER_PATH, audio_path, "--model", "tiny", "--language", "en",
             "--output_format", "txt", "--output_dir", out_dir,
             "--condition_on_previous_text", "False"],
            capture_output=True, text=True, timeout=60,
        )
        if result.returncode == 0:
            base = os.path.splitext(os.path.basename(audio_path))[0]
            txt_file = os.path.join(out_dir, base + ".txt")
            if os.path.exists(txt_file):
                with open(txt_file, encoding="utf-8") as f:
                    text = f.read().strip()
                for fname in os.listdir(out_dir):
                    os.unlink(os.path.join(out_dir, fname))
                os.rmdir(out_dir)
                return text
        log("Whisper failed: " + result.stderr[:300])
        return None
    except Exception as e:
        log("Transcribe error: " + str(e))
        return None


SYSTEM_PROMPT = (
    "You are Darleen's business partner and operator for The Grass Lady. "
    "Talk like a partner, not an assistant. No greetings, no 'Hey Darleen', no 'Hi there'. "
    "Just get straight to it. Warm, direct, no corporate tone. "
    "Like texting a business partner who already knows the context. "
    "Never suggest contacting SAM or Jereme. You handle everything. "
    "Never ask if Darleen wants to escalate. Just solve it."
)


def call_claude(message_text, chat_id=None):
    try:
        proc = subprocess.Popen(
            [CLAUDE_PATH, "-p", message_text, "--system-prompt", SYSTEM_PROMPT],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, cwd=WORK_DIR,
        )
        try:
            stdout, stderr = proc.communicate(timeout=300)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
            return "That one took too long. Break it into smaller pieces and I can handle each part."
        if proc.returncode == 0 and stdout.strip():
            return stdout.strip()
        if stderr.strip():
            return "Hit an issue: " + stderr.strip()[:500]
        return "Got your message but couldn't put a response together. Try rephrasing."
    except Exception as e:
        return "Something went wrong: " + str(e)[:200]


def main():
    log("The Grass Lady Telegram Bot starting...")
    me = api_call("getMe")
    if not me or not me.get("ok"):
        log("FATAL: Bot token invalid")
        sys.exit(1)
    botname = me.get("result", {}).get("username", "unknown")
    log("Bot: @" + botname)
    log("Voice: " + VOICE)

    offset = load_offset()

    while True:
        try:
            result = get_updates(offset)
            if not result or not result.get("ok"):
                time.sleep(5)
                continue

            for update in result.get("result", []):
                update_id = update["update_id"]
                offset = update_id + 1
                save_offset(offset)

                msg = update.get("message")
                if not msg:
                    continue

                msg_date = msg.get("date", 0)
                if msg_date < BOOT_TIME - 300:
                    log(f"Skipped stale message (date={msg_date}, boot={BOOT_TIME})")
                    continue

                user_id = msg.get("from", {}).get("id")
                chat_id = msg.get("chat", {}).get("id")
                text = msg.get("text", "")
                voice = msg.get("voice")
                audio = msg.get("audio")

                if user_id not in ALLOWED_USERS:
                    log("Ignored unauthorized user " + str(user_id))
                    continue

                if voice or audio:
                    file_id = (voice or audio).get("file_id")
                    if not file_id:
                        send_message(chat_id, "Could not read that voice message.")
                        continue
                    send_typing(chat_id)
                    audio_path = download_telegram_file(file_id)
                    if not audio_path:
                        send_message(chat_id, "Could not download the voice message.")
                        continue
                    text = transcribe_voice(audio_path)
                    os.unlink(audio_path)
                    if not text:
                        send_message(chat_id, "Could not transcribe that voice message. Try again or send text.")
                        continue
                    log("Transcribed voice: " + text)
                    send_message(chat_id, "Heard: " + text)

                if not text:
                    send_message(chat_id, "Send me a text or voice message.")
                    continue

                log("From " + str(user_id) + ": " + text)
                stop_typing = threading.Event()
                typer = threading.Thread(target=typing_loop, args=(chat_id, stop_typing), daemon=True)
                typer.start()

                response = call_claude(text, chat_id)
                stop_typing.set()
                typer.join(timeout=5)
                send_message(chat_id, response)

                voice_path = generate_voice(response)
                if voice_path:
                    send_voice(chat_id, voice_path)
                    os.unlink(voice_path)
                    log("Replied with text + voice")
                else:
                    log("Replied text only (TTS failed)")

        except KeyboardInterrupt:
            log("Shutting down.")
            break
        except Exception as e:
            log("Loop error: " + str(e))
            time.sleep(5)


if __name__ == "__main__":
    main()
