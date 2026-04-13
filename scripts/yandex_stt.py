#!/usr/bin/env python3
"""Распознавание голоса через Yandex SpeechKit"""

import os
import sys
import requests

CREDS_FILE = os.path.expanduser("~/.yandex-creds")

def load_creds():
    """Загружает credentials из файла"""
    creds = {}
    if os.path.exists(CREDS_FILE):
        with open(CREDS_FILE) as f:
            for line in f:
                if ":" in line:
                    key, val = line.strip().split(":", 1)
                    creds[key.strip()] = val.strip()
    return creds.get("api_key", ""), creds.get("folder_id", "")

API_KEY, FOLDER_ID = load_creds()

if not API_KEY or not FOLDER_ID:
    print("Error: ~/.yandex-creds not found or incomplete", file=sys.stderr)
    print("Expected format:", file=sys.stderr)
    print("  api_key: YOUR_API_KEY", file=sys.stderr)
    print("  folder_id: YOUR_FOLDER_ID", file=sys.stderr)
    sys.exit(1)

def recognize_voice(audio_path):
    if not os.path.exists(audio_path):
        return f"Error: File not found"

    with open(audio_path, "rb") as f:
        data = f.read()

    url = f"https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId={FOLDER_ID}&lang=ru-RU"
    headers = {"Authorization": f"Api-Key {API_KEY}"}

    try:
        r = requests.post(url, headers=headers, data=data, timeout=60)
        if r.status_code == 200:
            result = r.json()
            return result.get("result", "")
        else:
            return f"Error: {r.status_code} - {r.text}"
    except Exception as e:
        return f"Error: {str(e)}"

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 yandex_stt.py <audio_file>")
        sys.exit(1)

    result = recognize_voice(sys.argv[1])
    print(result)
