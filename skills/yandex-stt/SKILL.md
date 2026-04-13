# Yandex STT (Speech-to-Text)

Навык для распознавания речи из аудио через Yandex SpeechKit.

## API

- **URL:** `https://stt.api.cloud.yandex.net/speech/v1/stt:recognize`
- **Метод:** POST

## Аутентификация

Используется API Key из файла `~/.yandex-creds`.

## Пример использования

```bash
python3 ~/.scripts/yandex_stt.py <audio_file.ogg>
```

## Пример вызова

```python
import requests
import os

# Читаем креды из файла
creds = {}
with open(os.path.expanduser("~/.yandex-creds")) as f:
    for line in f:
        if ":" in line:
            key, val = line.strip().split(":", 1)
            creds[key.strip()] = val.strip()

API_KEY = creds.get("api_key", "YOUR_API_KEY")
FOLDER_ID = creds.get("folder_id", "YOUR_FOLDER_ID")

with open("audio.ogg", "rb") as f:
    data = f.read()

url = f"https://stt.api.cloud.yandex.net/speech/v1/stt:recognize?folderId={FOLDER_ID}&lang=ru-RU"
headers = {"Authorization": f"Api-Key {API_KEY}"}

r = requests.post(url, headers=headers, data=data, timeout=60)
result = r.json()
print(result.get("result", ""))
```

## Поддерживаемые форматы

- `oggopus` — рекомендуется (Telegram voice)
- `mp3`
- `wav`
- `flac`

## Языки

- `ru-RU` — русский
- `en-US` — английский

## Готовый скрипт

```bash
python3 ~/.scripts/yandex_stt.py ~/.openclaw/media/inbound/file_5.ogg
```
