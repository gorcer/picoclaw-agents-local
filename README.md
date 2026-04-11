# PicoClaw Agents

Изолированные PicoClaw агенты в Docker-контейнерах на удалённом сервере.

## Быстрый старт

```bash
# Создать агента
./agentctl.sh create myagent BOT_TOKEN

# Управление
./agentctl.sh list
./agentctl.sh logs myagent
./agentctl.sh restart myagent
./agentctl.sh stop myagent
```

## Структура

```
picoclaw-agents/
├── tester/          # Агент tester
│   ├── agent_config.json
│   └── workspace/
├── reviewer/        # Агент reviewer
│   ├── agent_config.json
│   └── workspace/
└── agentctl.sh     # Утилита управления
```

## Агенты

| Агент | Контейнер | Telegram Token |
|-------|-----------|----------------|
| tester | picoclaw-tester | @tester_bot |
| reviewer | picoclaw-reviewer | @reviewer_bot |

Каждый агент:
- Изолирован в Docker
- 100MB лимит диска (по умолчанию)
- Telegram бот с привязкой к чату 141455495
- Работает через прокси xray (socks5 → http)
