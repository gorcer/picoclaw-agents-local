# PicoClaw Agents

Изолированные PicoClaw агенты в Docker-контейнерах на удалённом сервере.

## Быстрый старт

```bash
# Создать агента
./agentctl.sh create myagent BOT_TOKEN API_KEY [user_chat_id] [size_mb]

# Примеры
./agentctl.sh create newbot 8193794728:AA... sk-9040...          # 100MB default
./agentctl.sh create bigbot 8193794728:AA... sk-9040... 500      # 500MB disk

# Управление
./agentctl.sh list
./agentctl.sh logs myagent
./agentctl.sh restart myagent
./agentctl.sh stop myagent
```

## Структура

```
picoclaw-agents-local/
├── agentctl.sh                    # Утилита управления агентами
├── agent_config.template.json     # Шаблон конфига агента
├── README.md
└── picoclaw-agents/               # Конфиги на srv (создаются автоматически)
    ├── tester/
    │   └── agent_config.json
    └── reviewer/
        └── agent_config.json
```

## Шаблон конфига

`agent_config.template.json` — base config для всех агентов:

```json
{
  "version": 2,
  "agents": {
    "defaults": {
      "workspace": "/workspace",
      "restrict_to_workspace": false,
      "allow_read_outside_workspace": true,
      "model_name": "minimax2",
      "max_tokens": 32768,
      "max_tool_iterations": 50
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "token": "{{TELEGRAM_TOKEN}}",
      "allow_from": ["{{USER_CHAT_ID}}"],
      "proxy": "http://host.docker.internal:10808"
    }
  },
  "model_list": [{
    "model_name": "minimax2",
    "model": "minimax/MiniMax-M2.7",
    "api_base": "http://62.106.66.13:3000/v1",
    "api_keys": ["{{API_KEY}}"],
    "extra_body": {"stream": false}
  }]
}
```

При создании агента placeholders заменяются:
- `{{TELEGRAM_TOKEN}}` → telegram bot token
- `{{API_KEY}}` → LLM API key
- `{{USER_CHAT_ID}}` → user chat ID (default: 141455495)

## Агенты

| Агент | Контейнер | Telegram Token |
|-------|-----------|----------------|
| tester | picoclaw-tester | @tester_bot |
| reviewer | picoclaw-reviewer | @reviewer_bot |

## Безопасность

Агенты работают с **почти полным доступом**:
- `restrict_to_workspace: false`
- `allow_read_outside_workspace: true`
- `max_tool_iterations: 50`

**Единственное ограничение**: `allow_from` — только авторизованный Telegram ID.

⚠️ Не запускай непроверенные агенты без нужды.

## OmniRoute Integration

PicoClaw работает с OmniRoute как прокси для LLM запросов.

### Важно: Model Alias

OmniRoute требует model alias для резолвинга моделей без prefix.

**Создание alias** (на сервере с OmniRoute):
```bash
curl -X PUT 'http://127.0.0.1:3000/api/models/alias' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer ТВОЙ_API_KEY' \
  -d '{"alias":"MiniMax-M2.7","model":"minimax/MiniMax-M2.7"}'
```

Где:
- `alias` — имя модели без prefix (то что отправляет picoclaw)
- `model` — полное имя с prefix (что ожидает провайдер)

**Проверить существующие alias:**
```bash
curl 'http://127.0.0.1:3000/api/models/alias' \
  -H 'Authorization: Bearer ТВОЙ_API_KEY'
```

### Streaming

OmniRoute по умолчанию возвращает SSE (streaming) ответы. PicoClaw Telegram channel работает с `streaming.enabled: false` — это обязательно для корректного парсинга ответов.

## Прокси

- xray: socks5 на `127.0.0.1:10808` (host)
- Внутри контейнера: `http://host.docker.internal:10808`
