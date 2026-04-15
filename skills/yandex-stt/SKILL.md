# Yandex STT (Speech-to-Text)

Навык для распознавания речи из голосовых сообщений Telegram.

## Использование

```bash
python3 ~/.scripts/yandex_stt.py <audio_file.ogg>
```

## Как работает

- Скрипт отправляет аудио на `http://host.docker.internal:5000/v1/audio/transcriptions`
- Прокси (`yandex_proxy.py`) добавляет API ключи и проксирует запрос в Yandex SpeechKit
- Ключи хранятся в `.env` на хосте, не в контейнере

## Поддерживаемые форматы

- `oggopus` — рекомендуется (Telegram voice)
- `mp3`
- `wav`
- `flac`

## Пример вызова

```python
import subprocess
result = subprocess.run(['python3', '~/.scripts/yandex_stt.py', 'voice_message.ogg'], capture_output=True, text=True)
print(result.stdout)
```

## Конфигурация

Прокси запущен на порту 5000 на хосте df2.

Переменные окружения (в `.env`):
- `YANDEX_API_KEY` — API ключ Yandex Cloud
- `YANDEX_FOLDER_ID` — ID папки в Yandex Cloud
