# Статус проекта BabichChat

> Полные таблицы статусов — в [`scenarios/index.md`](../scenarios/index.md).
> Здесь только сводка. Актуализируется после каждой сессии с прогрессом.

### Реализованные сценарии
- №1 Первый вход в дефолтный район ✅
- №1.1 Создание персонажа ✅
- №2 Первые выборы ✅ (backend + frontend, event-driven)
- №3.1 Заявка на рабочую лицензию ✅ (`RegisterWorkLicence` handler)
- №3.2 Меню работ — черновик, не реализован

### Технические задачи (масштабирование — см. architecture/realtime/scale-targets-and-redis.md)

| Задача | Статус |
|--------|--------|
| Реформа модели локаций (LocationUser, упразднение LocationPost, авто-членство удалено) | ✅ Реализовано (см. architecture/location/location-members-reform-plan.md) |
| Replay доменных событий из `event_publication` (JSON-десериализация Jackson) | ✅ Исправлено (см. architecture/event/domain-event-module-layers.md §6) |
| R2: STOMP Broker Relay (RabbitMQ/Artemis) вместо SimpleBroker | ❌ Не начат |
| R3: Presence/online-счётчики/unread → Redis | ❌ Не начат |
| R4: прод-конфиг (show-sql, ddl-auto → миграции, пул HikariCP, индексы) | ❌ Не начат |

### Безопасность и границы слоёв

| Задача | Статус |
|--------|--------|
| IDOR: `characterId`/`userId` из query-параметров проверяются на владельца (`ChatUserService.assertCharacterOwnedBy` / `assertAccountIsSelfOrAdmin`), закрытие выборов — только ADMIN | ✅ Реализовано |
| Границы слоёв chat: устранён цикл `engines.poll ↔ features.governorElection` (константа → `PollCheckType`), `ModuleBoundaryTest` без исключающих фильтров + тесты на исходниках | ✅ Реализовано (см. `architecture/modules/module-boundaries.md`) |
| JWT-секрет и логирование: `jwt.secret` из `${JWT_SECRET}`, в лог не попадает кусок токена | ✅ Реализовано |
