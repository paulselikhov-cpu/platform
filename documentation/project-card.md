# BabichChat

Ролевой мессенджер в сеттинге постсоветского пространства с социальной экономикой.
Жители общаются в текстовых локациях, зарабатывают монеты, прокачивают персонажа,
создают бизнес, вступают в группировки.

**Стек:** Java (Spring) backend + Angular (platform-ui) frontend + PostgreSQL + Redis.

---

## Быстрые ссылки

| Раздел | Файл | Кто пишет/обновляет | Описание |
|--------|------|----------------------|----------|
| **Статус проекта** | [`status/project-status.md`](status/project-status.md) | AI | Модульная структура, что реализовано, план MVP, игровой цикл, открытые вопросы |
| **Полная концепция** | [`vision/concept.md`](vision/concept.md) | Человек | Полное описание всех игровых механик, ролей, экономики (читать по необходимости) |
| **Системная модель** | [`system-model/mvp-ai-brief.md`](system-model/mvp-ai-brief.md) | AI | Концепция на языке системы: Entity/Service/Enum по разделам концепции |
| **Команды** | [`commands.md`](commands.md) | AI (актуализирует) | Рабочие команды для сборки/запуска backend, frontend, Docker |
| **Диаграммы** | [`diagrams/`](diagrams/) | Человек | Только для человека, AI не открывает |

## Архитектурные заметки (AI, "как реализовано")

| Тема | Файл |
|------|------|
| Event-driven архитектура (концепция) | [`architecture/event/babichchat-event-architecture.md`](architecture/event/babichchat-event-architecture.md) |
| Event-driven архитектура (план миграции) | [`architecture/event/event-migration-plan.md`](architecture/event/event-migration-plan.md) — Этапы 1, 1.5, 2, 3, 4, 5, 6 ✅, следующий — 7 |
| Как пользоваться event-архитектурой (инструкция для разработчика) | [`architecture/event/how-to-use-event-architecture.md`](architecture/event/how-to-use-event-architecture.md) — простым языком: ментальная модель, словарик, рецепт нового сценария, примеры из кода, DoD |
| Read status / seen-by | [`architecture/chat/read-status.md`](architecture/chat/read-status.md) |
| Лавина планировщиков при clock leap (fixedRate → fixedDelay) | [`architecture/chat/scheduler-clock-leap-fixed-rate-avalanche.md`](architecture/chat/scheduler-clock-leap-fixed-rate-avalanche.md) |
| Синхронизация LocationUsersMenu | [`architecture/presence/location-users-menu-sync.md`](architecture/presence/location-users-menu-sync.md) |
| Presence-архитектура | [`architecture/presence/online-tracking.md`](architecture/presence/online-tracking.md) |
| Ранняя подписка на WS-топики | [`architecture/websocket/early-topic-subscription.md`](architecture/websocket/early-topic-subscription.md) |
| Stomp/Chat сервисы | [`architecture/websocket/stomp-and-chat-service.md`](architecture/websocket/stomp-and-chat-service.md) |
| Районы и системные локации | [`architecture/world/districts-and-public-locations.md`](architecture/world/districts-and-public-locations.md) |
| Должности в системных локациях (LocationPost) | [`architecture/world/districts-and-public-locations.md`](architecture/world/districts-and-public-locations.md) |
| Четырёхслойная архитектура election-сценария | [`scenarios/the-first-election.md`](scenarios/the-first-election.md) (см. таблицы Layers 1–4) |

## Сценарии

| Сценарий | Статус | Файл |
|----------|--------|------|
| №1. Первый вход в дефолтный район | ✅ Реализовано | [`scenarios/entry-default-district.md`](scenarios/entry-default-district.md) |
| №2. Первые выборы | ✅ Реализовано (backend, Event-Driven: ElectionResultHandlerAdapter + PollClosedEvent) | [`scenarios/the-first-election.md`](scenarios/the-first-election.md) |

## Прогресс MVP

| # | Шаг | Статус |
|---|-----|--------|
| 1 | Экономический слой (монеты, XP, энергия, RewardService) | ✅ |
| 2 | Профессия «дворник» + статус «бомж» | ✅ |
| 3 | Покупка первой локации через Application | ✅ |
| 4–6 | Группировки (Воры, Проститутки) | ❌ |
| 7 | Полицейский участок | ❌ |
| 8 | Банк | ❌ |
| 9 | Рынок (аренда прилавков) | ❌ |
| 10 | Заглушка рынка недвижимости | ❌ |
| 11 | LocationPost — должности в системных локациях | ✅ |
| 12 | Авто-членство в системных локациях | ✅ |