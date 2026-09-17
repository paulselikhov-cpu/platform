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
| R2: STOMP Broker Relay (RabbitMQ/Artemis) вместо SimpleBroker | ❌ Не начат |
| R3: Presence/online-счётчики/unread → Redis | ❌ Не начат |
| R4: прод-конфиг (show-sql, ddl-auto → миграции, пул HikariCP, индексы) | ❌ Не начат |
