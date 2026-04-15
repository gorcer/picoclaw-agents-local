#!/usr/bin/env python3
"""Распознавание голоса через Yandex SpeechKit Proxy"""

import os
import sys
import requests

# Прокси URL - по умолчанию host.docker.internal:5000 (для контейнеров на том же хосте)
PROXY_URL = os.environ.get('YANDEX_STT_PROXY', 'http://host.docker.internal:5000/v1/audio/transcriptions')

def recognize_voice(audio_path):
    if not os.path.exists(audio_path):
        return f"Error: File not found"

    with open(audio_path, "rb") as f:
        data = f.read()

    try:
        r = requests.post(PROXY_URL, files={'file': ('audio.ogg', data, 'audio/ogg')}, timeout=60)
        if r.status_code == 200:
            result = r.json()
            return result.get("text", "")
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
