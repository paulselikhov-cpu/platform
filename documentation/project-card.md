# BabichChat

Ролевой мессенджер в сеттинге постсоветского пространства с социальной экономикой.
Жители общаются в текстовых локациях, зарабатывают монеты, прокачивают персонажа,
создают бизнес, вступают в группировки.

**Стек:** Java (Spring) backend + Angular (platform-ui) frontend + PostgreSQL + Redis.

---

## Быстрые ссылки

| Раздел | Файл | Кто пишет/обновляет | Описание |
|--------|------|----------------------|----------|
| **Статус проекта** | [`status/project-status.md`](status/project-status.md) | AI | Сводка прогресса, техзадачи масштабирования |
| **Сценарии (индекс)** | [`scenarios/index.md`](scenarios/index.md) | Гибрид | Все сценарии и их статусы |
| **Полная концепция** | [`vision/concept.md`](vision/concept.md) | Человек | Игровые механики, роли, экономика (читать по необходимости) |
| **Системная модель (карта кода)** | [`system-model/mvp-ai-brief.md`](system-model/mvp-ai-brief.md) | AI | Что реально есть в коде: модули, сущности, где искать |
| **Шпаргалка фронт↔бэк** | [`architecture/front-back-communication.md`](architecture/front-back-communication.md) | AI | Все REST-ручки и WS-топики |
| **Команды** | [`commands.md`](commands.md) | AI (актуализирует) | Сборка/запуск backend, frontend, Docker |

## Архитектурные заметки (AI, "как реализовано")

| Тема | Файл |
|------|------|
| Event-driven архитектура (концепция и паттерны) | [`architecture/event/babichchat-event-architecture.md`](architecture/event/babichchat-event-architecture.md) |
| Как пользоваться event-архитектурой (инструкция) | [`architecture/event/how-to-use-event-architecture.md`](architecture/event/how-to-use-event-architecture.md) — ментальная модель, рецепт нового сценария, DoD |
| Read status / seen-by | [`architecture/chat/read-status.md`](architecture/chat/read-status.md) |
| Лавина планировщиков при clock leap (fixedRate → fixedDelay) | [`architecture/chat/scheduler-clock-leap-fixed-rate-avalanche.md`](architecture/chat/scheduler-clock-leap-fixed-rate-avalanche.md) |
| RoomView / RoomFeature — фичи комнат | [`architecture/chat/room-feature.md`](architecture/chat/room-feature.md) |
| Синхронизация LocationUsersMenu | [`architecture/presence/location-users-menu-sync.md`](architecture/presence/location-users-menu-sync.md) |
| Presence-архитектура | [`architecture/presence/online-tracking.md`](architecture/presence/online-tracking.md) |
| Ранняя подписка на WS-топики | [`architecture/websocket/early-topic-subscription.md`](architecture/websocket/early-topic-subscription.md) |
| Stomp/Chat сервисы | [`architecture/websocket/stomp-and-chat-service.md`](architecture/websocket/stomp-and-chat-service.md) |
| Целевой масштаб 100k+ и Redis; этапы R1–R5 | [`architecture/realtime/scale-targets-and-redis.md`](architecture/realtime/scale-targets-and-redis.md) |
| Районы и системные локации, LocationPost | [`architecture/world/districts-and-public-locations.md`](architecture/world/districts-and-public-locations.md) |
| Реактивное обновление персонажа (character-updated push) | [`architecture/reactive-character-updates.md`](architecture/reactive-character-updates.md) |
| Четырёхслойная архитектура election-сценария | [`scenarios/2. the-first-election.md`](scenarios/2.%20the-first-election.md) (таблицы Layers 1–4) |