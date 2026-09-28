# Доменные события: ядро шины и подписчики

> Факты о текущей реализации (после рефакторинга модуля `domainEvent`).
> Инструкция «как пользоваться» — [`how-to-use-event-architecture.md`](how-to-use-event-architecture.md),
> зачем это всё — [`babichchat-event-architecture.md`](babichchat-event-architecture.md),
> карта кода — `system-model/mvp-ai-brief.md`.

## 1. Два слайса вместо одного «перемкнутого»

| Слайс | Пакет | Роль |
|---|---|---|
| Ядро событий | `com.platform.chat.core.modules.domainEvent` | Конверт `DomainEvent`, словарь фактов `EventType`, `enums/ScopeType`, **конкретные события `events/*`** (7 фактов), порт публикации `service/DomainEventPublisher` |
| Реакции (Слой 4 «Доставка») | `com.platform.chat.modules.domainEvent` | Подписчики `listeners/*`: `NotificationEventListener`, `CharacterUpdatedEventListener`, `TransactionLogEventListener` |

Зависимость строго однонаправленная: `chat.modules.domainEvent → chat.core.modules.domainEvent`.
Ядро событий не знает ни про подписчиков, ни про `chat.base.chatUser`, ни про web.

Почему так, а не «события в фич-слайсе подписчиков»:

- события-факты публикуют **ядра процессов** (`core.modules.application`, `core.modules.poll`)
  и фич-модули (`coin`, `governorElection`). Если бы события лежали в фиче, каждый
  публикатор тянул бы фич-слайс — направленный цикл «ядро ↔ исполнители»,
  ровно тот дефект, что был с `ApplicationType` в модуле заявок
  (`architecture/application/application-module-layers.md`, § 1);
- до рефакторинга цикл между слайсами существовал физически: ядро объявляло
  `allowedDependencies = {"chat.modules.domainEvent"}` (реестр `@JsonSubTypes`
  перечислял классы из фич-пакета), а фич-слайс объявлял зависимость на ядро;
- теперь `chat.modules.domainEvent` — лист: наружу его не импортирует ни один
  модуль, поэтому и цикла нет. Ядра процессов зависят только от
  `chat.core.modules.domainEvent`.

## 2. Что где лежит

| Класс | Пакет | Ответственность |
|---|---|---|
| `DomainEvent` | ядро | конверт: `type`, `actorId`, `targetId`, `scopeType`, `scopeId`, `payload`; реестр подтипов `@JsonSubTypes`; хелпер чтения числового payload `longPayload` |
| `EventType` | ядро | словарь «что произошло» (одно значение на факт) |
| `ScopeType` | ядро | «где произошло»: `CHARACTER`, `DISTRICT`, `PARLIAMENT`, `GANG` |
| `events/ApplicationResolvedEvent` | ядро | заявка решена (APPROVED/REJECTED) |
| `events/CharacterUpdatedEvent` | ядро | персонаж изменился |
| `events/CoinsChangedEvent`, `events/XpChangedEvent` | ядро | баланс монет / XP изменился |
| `events/ElectionStartedEvent`, `events/ElectionClosedEvent` | ядро | выборы губернатора начались / закрылись |
| `events/PollClosedEvent` | ядро | любое голосование закрылось |
| `service/DomainEventPublisher` | ядро | единственная точка публикации (обёртка над Spring `ApplicationEventPublisher`) |
| `listeners/NotificationEventListener` | реакции | `Notification` в БД + WS-пуш в `/queue/notifications` |
| `listeners/CharacterUpdatedEventListener` | реакции | WS-пуш в `/queue/character-updated` (фронт делает `refresh()`) |
| `listeners/TransactionLogEventListener` | реакции | аудит-запись в `TransactionLog` (COIN / XP_USER) |

Словарь `CoinUpdateReason` живёт в ядре аудита —
`core.modules.transactionLog.enums.CoinUpdateReason`, а не в `modules.coin`: колонка
`transaction_logs.reason` типизирована этим enum (`@Enumerated(STRING)`), а события
несут причину в payload. До переноса ядро аудита зависело от фич-модуля кошелька.

## 3. Кто публикует события

Правило: **факт публикует тот, кто произвёл изменение, — в той же транзакции.**
Подписчик про публикатора не знает.

| Событие | Публикатор | Когда |
|---|---|---|
| `ApplicationResolvedEvent` | `ApplicationService` (ядро заявок) | после `save` решения по заявке |
| `CharacterUpdatedEvent` | ядро заявок — циклом `decision.events()` | факт отдаёт стратегия в `ApplicationDecision`, ядро только публикует (типов не знает) |
| `CoinsChangedEvent`, `XpChangedEvent` | `CoinService` (`modules.coin`) | `giveCoins` / `takeCoins` / `giveXp` |
| `ElectionStartedEvent`, `ElectionClosedEvent` | `ElectionService` (`modules.governorElection`) | инициация / закрытие выборов |
| `PollClosedEvent` | `PollResultDispatcher` (ядро голосований) | после обработки результата любого голосования |

## 4. Контракт подписчика

- подписка — `@ApplicationModuleListener` (Modulith: AFTER_COMMIT + outbox
  `event_publication`); событие может быть доставлено повторно после рестарта,
  если процесс упал между коммитом и обработкой;
- собственная `@Transactional` у подписчика допускается только с
  `REQUIRES_NEW` / `NOT_SUPPORTED` (пример — `TransactionLogEventListener`:
  аудит пишется независимо от успеха бизнес-транзакции);
- один метод — одно семейство последствий; обязательный эффект (списание +
  выдача роли) остаётся синхронным вызовом, а не событием;
- подписчик читает данные по id из события, полные сущности запрашивает сам.

## 5. Границы модулей

| Пакет | `allowedDependencies` | `type` |
|---|---|---|
| `chat.core.modules.domainEvent` | `chat.core.modules.transactionLog` (словарь причин) | `OPEN` |
| `chat.modules.domainEvent` | `chat.base.chatUser`, `chat.core.modules.domainEvent`, `chat.core.modules.notification`, `chat.core.modules.transactionLog` | `OPEN` |

`type = CLOSED` у слайса реакций не выставлен, поэтому тип модуля — `OPEN`:
закрытый модуль запретил бы обращаться к классам подписчиков извне, а такое
обращение есть у теста `com.platform.notification.listener.NotificationEventListenerTest`
(он лежит вне дерева `com.platform.chat.*`). Тест границ `ModuleBoundaryTest`
проверяет `detectViolations()`: незаявленная зависимость или **новый** цикл
валят тест (фильтруется только известный предсуществующий цикл `chat ↔ economy`).

## 6. Сериализация и replay

Факты (проверено на Modulith 2.1.0 в этом проекте):

- хранилище — таблица `event_publication`, колонка `serialized_event`
  `varchar(255)`; подтип восстанавливается по **логическому имени** из
  `@JsonTypeInfo(use = Id.NAME, property = "eventType")` — FQCN в контракте нет,
  поэтому перенос событий в другой пакет replay не ломает;
- рантайм-сериализатор — `org.springframework.modulith.events.jackson.JacksonEventSerializer`
  (в контексте есть Jackson 2 `ObjectMapper`), т.е. пишется JSON, а не Java
  serialization;
- Jackson **не наследует** `@JsonCreator` абстрактного базового класса: у каждого
  факта объявлен собственный `@JsonCreator`-конструктор, восстанавливающий поля
  конверта. Без него replay падал с `InvalidDefinitionException` («no Creators»);
- `scopeType` имеет геттер и входит в JSON: без него поле терялось при replay;
- числа из payload Jackson возвращает как `Integer` (типовой информации в
  `Map<String, Object>` нет), поэтому события читают их через
  `DomainEvent.longPayload(key)`; прямые касты `(Long) payload.get(...)` падали бы
  с `ClassCastException` на переигранном событии;
- контракт зафиксирован тестом
  `core/modules/domainEvent/DomainEventSerializationTest`: round-trip каждого факта
  по базовому типу `DomainEvent`, работа вычисляемых геттеров после replay и
  влезаемость JSON в 255 символов.

Новое событие считается «зарегистрированным», если оно есть и в `EventType`, и в
`@JsonSubTypes`, и имеет `@JsonCreator` + покрыто этим тестом.

## 7. Сохранённые контракты и известные ограничения

- JSON-формат событий (имена свойств `eventType`, `type`, `actorId`, `targetId`,
  `scopeType`, `scopeId`, `payload`) наружу (REST/WS) не отдаётся — это
  внутренний контракт шины и таблицы `event_publication`;
- значения enum `CoinUpdateReason` и его JPA-маппинг не менялись при переносе —
  схема и данные `transaction_logs` те же;
- тексты уведомлений захардкожены в `NotificationEventListener` (не в
  `messages.properties`), а имена типов/статусов заявок он сопоставляет
  строками (`"REGISTER_PASSPORT"`, `"APPROVED"`), т.е. дублирует словарь ядра
  заявок;
- `EventType` содержит значения, которые пока никто не публикует:
  `NOTIFICATION_SENT`, `CAMPAIGN_FINISHED`, `POLL_CREATED`;
- `ScopeType` существует в двух экземплярах — в ядре событий и в
  `core.modules.poll.enums` (значения совпадают); `PollClosedEvent` маппит их по
  имени строки;
- лимит 255 символов означает, что событие с большим payload в
  `event_publication` не влезет — при добавлении фактов это проверяет
  `DomainEventSerializationTest`;
- `payload` не типизирован: смысл ключей знает только событие и его подписчик.
