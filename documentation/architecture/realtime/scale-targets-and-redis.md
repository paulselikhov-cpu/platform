# Целевой масштаб (100k+ онлайн) и Redis как realtime-инфраструктура

> Зафиксировано: 2026-09-11 (решение владельца проекта).
> **Продукт:** ролевой онлайн-мессенджер — десктоп сейчас, мобильный клиент в будущем
> (React Native, те же REST/WebSocket эндпоинты — см. concept.md §9).
> **Целевой одновременный онлайн — 100 000+ пользователей** (уровень мессенджеров).
> **Скорость и оптимизация — приоритет разработки.**

---

## Как реализовано сейчас (факты)

| Компонент | Реализация |
|---|---|
| Web-стек | Spring Boot 4.0.7, `spring-boot-starter-webmvc` (Tomcat, блокирующая модель) |
| Realtime | STOMP over WebSocket (`spring-boot-starter-websocket`), эндпоинт `/ws` |
| Брокер | `enableSimpleBroker("/topic", "/queue")` — встроенный брокер **в памяти одной JVM** (`WebSocketConfig`) |
| Fan-out | `SimpMessagingTemplate.convertAndSend / convertAndSendToUser` — `MessageService`, `UnreadService`, `PresenceService`, `NotificationEventListener` |
| Presence | PostgreSQL (`CharacterPresenceRepository`), периодическая очистка через TickHandler |
| События | Spring Modulith `events-jpa` — персистентный registry (`event_publication`) в PostgreSQL |
| Redis | **Не подключён**: нет зависимости в `pom.xml`, нет контейнера в `docker-compose` (заявлен в стеке `project-card.md` и в `concept.md` §9 как TTL-хранилище — это план) |
| Heartbeat | STOMP 10s/10s, `ThreadPoolTaskScheduler` с пулом = 1 (`WebSocketConfig`) |
| HTTP | nginx (reverse proxy, `docker-compose`) перед приложением |

---

## Узкие места этой схемы при 100k+

1. **SimpleBroker не масштабируется.** Живёт в памяти одного инстанса: fan-out
   (одно сообщение → N подписчиков комнаты) выполняется в той же JVM, а несколько
   инстансов приложения не видят подписки друг друга — горизонтально не расширяется.
2. **Presence в PostgreSQL.** При 100k+ онлайн каждая смена комнаты/локации — это
   запись в БД + broadcast. Hot-path нагружает PostgreSQL постоянно.
3. **Modulith `events-jpa` пишет каждое событие в PostgreSQL.** Для MVP корректно;
   при росте темпа событий транспорт заменяется без переписывания контракта
   `DomainEvent` и подписчиков (событие — неизменяемый контракт, транспорт меняется
   конфигурацией).
4. **Блокирующий JPA/JDBC.** WebFlux сам по себе это не лечит; ограничителем становится
   пул соединений к БД.

---

## Принятое целевое решение

1. **Внешний STOMP-брокер через `enableStompBrokerRelay`** — нативный путь Spring:
   **RabbitMQ (со STOMP-плагином) или ActiveMQ Artemis** как внешний STOMP-брокер.
   Redis сам по себе STOMP-брокером **не является** — он не умеет STOMP-протокол,
   поэтому как шина для fan-out не годится напрямую. Код контроллеров и
   `SimpMessagingTemplate` **не меняется** — меняется только конфигурация брокера
   (`WebSocketConfig`). Снимает ограничение «все подписчики на одном инстансе»,
   даёт горизонтальное масштабирование.
2. **Presence, online-счётчики, unread-счётчики — в Redis** (сейчас в PostgreSQL).
   Контракт для клиента не меняется: те же WS-топики (`/topic/location.{id}.presence`,
   `/topic/locations.presence-counts`) и те же REST-эндпоинты.
3. **Кулдауны / энергия / квоты — Redis TTL** (заложено в `concept.md` §9) —
   реализуется тем же подключением Redis, что и п.2.
4. **Горизонтальное масштабирование:** несколько инстансов `babich-app` за nginx;
   WS-соединения sticky; общий брокер и общий Redis делают инстансы взаимозаменяемыми.
5. **WebFlux/Netty — опциональный этап, не решение.** Он дёшево держит много
   простаивающих WS-соединений на одном инстансе, но не решает fan-out и нагрузку на
   БД. Рассматривается только после пп. 1–4 и только если профилирование покажет,
   что потоки Tomcat на удержании соединений — реальное узкое место.

---

## Порядок внедрения

| Этап | Что | Статус |
|---|---|---|
| R1 | Контейнер Redis в `docker-compose.yml` (порт 6379) | ✅ 2026-09-11 |
| R2 | STOMP Broker Relay (RabbitMQ/Artemis) вместо SimpleBroker | ❌ Не начат |
| R3 | Presence / online-счётчики / unread → Redis | ❌ Не начат |
| R4 | Прод-конфиг: `show-sql: false`, `ddl-auto` → миграции, пул HikariCP, индексы горячих запросов | ❌ Не начат |
| R5 | (опционально, по профилированию) WebFlux/Netty | ❌ Не начат |

---

## Почему не WebFlux первым шагом

WebFlux меняет модель исполнения запросов, но не меняет архитектуру рассылки:
SimpleBroker остался бы in-JVM, JPA остался бы блокирующим. Основные затраты при
100k+ — fan-out сообщений и записи presence, а не удержание простаивающих
соединений. Поэтому сначала внешний брокер + Redis, потом реактивный транспорт —
и только по данным профилирования.

---

## Связанные документы

- [`architecture/presence/online-tracking.md`](../presence/online-tracking.md) — текущая presence-схема (PostgreSQL)
- [`architecture/event/babichchat-event-architecture.md`](../event/babichchat-event-architecture.md) — событийная архитектура
- [`vision/concept.md`](../../vision/concept.md) §9 — Redis TTL для кулдаунов/энергии (пишется человеком)