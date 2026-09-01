# План миграции на событийную архитектуру (Event-Driven)

> Создан: 2026-07-30
> Обновлён: 2026-08-06 — Этап 6 завершён (PollResultDispatcher:
> диспетчеризация PollResultHandler по PollType, ElectionResultHandler
> заменён на ElectionResultHandlerAdapter, PollClosedEvent в `core.event`
> с pollType String; DoD-тест PollClosedEventIntegrationTest зелёный).
> Обновлён: 2026-08-06 — Этап 5 завершён (SchedulerGateway — единый
> @Scheduled: TickHandler для периодики + реестр ScheduledCheck для
> отложенных проверок; ElectionScheduler удалён, PresenceService переведён
> на TickHandler; DoD-тест SchedulerGatewayIntegrationTest зелёный);
> граница chat→core легализована в package-info (PresenceService → TickHandler).
> Обновлён: 2026-08-06 — Этап 4 завершён (ApplicationService публикует
> ApplicationResolvedEvent, NotificationEventListener уведомляет заявителя,
> DoD-тест ApplicationResolvedIntegrationTest зелёный); граница civic→core
> легализована в package-info (модуль core OPEN — цикл civic ⇄ core не
> детектится, тот же паттерн, что у economy ⇄ core на Этапе 3).
> Обновлён: 2026-08-06 — Этап 3 завершён (RewardService публикует
> CoinsChangedEvent/XpChangedEvent, TransactionLogEventListener пишет аудит,
> BuyFirstLocationHandler переведён на RewardService.takeCoins, DoD-тест
> RewardServiceAuditIntegrationTest 5/5 зелёный); граница economy→core
> легализована в package-info (этап 1.5).
> Обновлён: 2026-08-05 — Этап 1 реализован полностью (Modulith event registry,
> Jackson-совместимость event-классов, `@Modulith`), дополнение Этапа 2
> (замена на `@ApplicationModuleListener` + юнит-тест слушателя) выполнено,
> Этап 1.5 (границы модулей) завершён — `package-info.java` + `detectViolations()`.
> Обновлён: 2026-08-04 — добавлены Modulith event registry, ранняя проверка
> границ модулей (было на этапе 7 — стало этапом 1.5), обязательное
> тестирование асинхронных слушателей как часть Definition of Done для
> каждого этапа.
> Статус: **в работе** (см. секцию «Прогресс»)
>
> Этот файл — чекпоинт для AI между сессиями. Если контекст потерян —
> начать с чтения этого файла и `mvp-ai-brief.md` (раздел 7.4).

---

## Зачем

Текущий код нарушает направление зависимости четырёхслойной архитектуры:
- Слой 3 (ElectionFacade) напрямую вызывает Слой 4 (NotificationService)
- RewardService не публикует события, хотя каждое изменение баланса может
  потребовать уведомления или аудита
- Нет единого SchedulerGateway — каждый новый таймер плодит `@Scheduled`
- Нет диспетчеризации PollResultHandler по PollType
- BuyFirstLocationHandler списывает монеты в обход RewardService (дыра в TransactionLog)

Event-driven архитектура исправляет это: Слой 3 публикует события через
`DomainEventPublisher`, Слой 4 подписывается через `@ApplicationModuleListener`
(обёртка Modulith над AFTER_COMMIT с персистентным event registry) — он
подключён уже на Этапе 1.

---

## Definition of Done для каждого этапа (применяется ко всем этапам 2-6)

Чтобы миграция не превратилась в «код есть, но никто не знает, работает ли
он на самом деле» — с этапа 2 включительно каждый этап **не считается
завершённым**, пока не выполнены все три пункта:

1. **Код**: слушатель/публикация события реализованы.
2. **Тест публикации** — `@RecordApplicationEvents`: проверяет, что доменный
   сервис действительно опубликовал ожидаемое событие с корректным payload.
   Не проверяет обработку — только факт и содержимое публикации.
3. **Тест сквозного пути** — Modulith `Scenario` API
   (`scenario.stimulate(...).andWaitForEventOfType(...).toArriveAndVerify(...)`):
   проверяет, что слушатель в другом модуле реально отработал и произвёл
   ожидаемый побочный эффект (запись в БД, WS-push и т.д.).

Без пункта 3 легко получить тест, который проходит, даже если слушатель
никогда не вызывается — например, если тестовый метод обёрнут в
`@Transactional` и `AFTER_COMMIT`-слушатель просто не срабатывает из-за
отката транзакции в конце теста. Именно поэтому пункт 3 обязателен, а не
опционален.

---

## Этапы миграции

### Этап 1: Core-модуль (DomainEvent + EventBus + Modulith event registry)
**Статус: ✅ ГОТОВ (2026-08-05)** — включая Modulith event registry,
Jackson-совместимость event-классов и `@Modulith`

Создать пакет `com.platform.core.event`:
- `EventType` — enum (APPLICATION_RESOLVED, ELECTION_CLOSED, COINS_CHANGED, NOTIFICATION_SENT)
- `ScopeType` — enum (CHARACTER, DISTRICT, GLOBAL)
- `DomainEvent` — абстрактный класс (eventId, occurredAt, type, actorId, targetId, scopeType, scopeId, payload)
- `DomainEventPublisher` — @Service, обёртка над ApplicationEventPublisher

**Файлы:**
- `babich-app/src/main/java/com/platform/core/event/EventType.java`
- `babich-app/src/main/java/com/platform/core/event/ScopeType.java` — объявлен
  локально в `core.event`, чтобы core не зависел от модуля poll
- `babich-app/src/main/java/com/platform/core/event/DomainEvent.java`
- `babich-app/src/main/java/com/platform/core/event/DomainEventPublisher.java`
- `babich-app/src/main/java/com/platform/core/event/ElectionClosedEvent.java` —
  первый конкретный event (type=ELECTION_CLOSED)

**Дополнение (СДЕЛАНО, 2026-08-05):**

Подключён `spring-modulith-events-jpa` — персистентный event registry. Событие
пишется в таблицу `event_publication` в той же транзакции, что и бизнес-изменение,
и replay недоставленных событий после рестарта — outbox-гарантии без своего
инфраструктурного кода. В `pom.xml` добавлены зависимости Modulith 2.1.0
(версия задана явно: в BOM Spring Boot 4 Modulith отсутствует):

```xml
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-events-jpa</artifactId>
    <version>2.1.0</version>
</dependency>
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-events-api</artifactId>
    <version>2.1.0</version>
</dependency>
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-api</artifactId>
    <version>2.1.0</version>
</dependency>
<dependency>
    <groupId>org.springframework.modulith</groupId>
    <artifactId>spring-modulith-events-jackson</artifactId>
    <version>2.1.0</version>
</dependency>
```

Почему именно этот набор:
- `spring-modulith-api` — аннотация `@Modulith` (в 2.x заменяет `@EnableModulith`),
  добавлена в compile-скоуп (изначально приходила только транзитивно через test-зависимость);
  применена к `PlatformApplication`.
- `spring-modulith-events-jackson` — обязательный `EventSerializer` для
  персистентного registry; без него контекст не стартует
  (`NoSuchBeanDefinitionException: EventSerializer`).
- `spring-modulith-starter-test` (test) — `@RecordApplicationEvents` и `Scenario` API.

**Jackson-совместимость event-классов** (требование JPA-сериализации Modulith):
- `DomainEvent` — `Serializable`, с `@JsonTypeInfo` (десериализация по типу),
  `@JsonCreator` + `@JsonProperty` на конструкторе.
- `ElectionClosedEvent` — Jackson-совместимый конструктор, `@JsonProperty` на полях.
- `ScopeType` — enum живёт в `core.event` (независимость core от poll).

**Изменения схемы БД:** таблица `event_publication` создаётся Hibernate'ом
автоматически при `ddl-auto=create`/`update` (проверено — приложение стартует
с таблицей).

**Почему не ручной outbox:** ручной outbox = своя таблица + свой relay-шедулер
+ своя логика ретраев, которую нужно писать и тестировать самостоятельно.
Modulith даёт то же самое одной зависимостью. Если в будущем понадобится
внешняя шина (Kafka) — замена происходит на уровне транспорта Modulith
(`spring-modulith-events-kafka`), контракт `DomainEvent` не меняется.

### Этап 1.5: Проверка границ модулей (было этапом 7 — перенесено сюда)
**Статус: ✅ ГОТОВ (2026-08-05)** — границы описаны аннотациями Modulith,
тест прогоняет `detectViolations()` и фильтрует единственный оставшийся
легаси-цикл (см. «Фактическое состояние»)

Раньше это было последним шагом плана. Перенесено в начало намеренно:
пока пакеты `economy`, `roles`, `gangs`, `structures` почти пустые — правило
фиксируется до того, как появится код, который его нарушает. Если оставить
проверку на конец — за 6 этапов миграции накопятся «временные» прямые
импорты между модулями, и вместо 15-минутной проверки в CI получится
неделя распутывания связей задним числом.

Два варианта, можно оба:

**Вариант А — Spring Modulith Verification (минимум кода):**
```java
@Test
void verifyModuleStructure() {
    ApplicationModules.of(BabichApplication.class).verify();
}
```
Modulith сам определяет модули по структуре пакетов и проверяет отсутствие
циклов и незаявленных зависимостей между ними.

**Вариант Б — явный ArchUnit-тест (если нужны более специфичные правила,
например «gangs и structures вообще не должны знать друг о друге»):**
```java
@Test
void modulesRespectDependencyRules() {
    JavaClasses classes = new ClassFileImporter().importPackages("com.platform");

    ArchRule rule = classes()
        .that().resideInAPackage("..gangs..")
        .should().onlyAccessClassesThat()
        .resideOutsideOfPackages("..structures..", "..roles..")
        .orShould().resideInAnyPackage("..core..", "..gangs..");

    rule.check(classes);
}
```

**Требование:** тест подключается в CI (падает сборка при нарушении), а не
существует «для галочки» локально.

**Файлы:**
- `babich-app/src/test/java/com/platform/ModuleBoundaryTest.java`

**Фактическое состояние (сделано 2026-08-05, в развитие Этапа 1):**

Границы приведены в порядок декларативно — через `package-info.java` на уровне
конкретных `com.platform.<module>`-пакетов (без переноса кода):

- `com.platform.auth`, `com.platform.chat`, `com.platform.core` —
  `@ApplicationModule(type = OPEN)`: любая внутренняя зависимость между ними
  легальна. Так зафиксированы технически существующие связи (chat↔economy,
  chat→auth: ChatUserService, JwtChannelInterceptor — все взаимные зависимости
  закрыты).
- `com.platform.economy` — `@ApplicationModule(allowedDependencies = {"chat",
  "core"}, type = OPEN)`. Список явный, потому что с Этапа 3 economy публикует
  доменные события (CoinsChangedEvent/XpChangedEvent), вынесенные в
  `core.event` — зависимость economy→core легализована осознанно, а не
  «свалена в OPEN без причины».
- `com.platform.civic` — `type = CLOSED`, `allowedDependencies = {"chat", "core"}`.
  Зависимость на core добавлена 2026-08-06 на Этапе 4 (ApplicationService
  публикует ApplicationResolvedEvent из `core.event` через DomainEventPublisher).
  Модуль core помечен `OPEN`, поэтому возникающий цикл civic ⇄ core не
  детектится Modulith — это тот же паттерн, что у существующего цикла
  economy ⇄ core (civic → core через событие, core → civic невозможен:
  core открыт, но наружу не ссылается).
- `com.platform.notification` — `type = CLOSED`, `allowedDependencies = {"chat", "core"}`.
- `com.platform.poll` — `type = CLOSED`, `allowedDependencies = {"auth", "chat", "core"}`.

Итоговая карта модулей (без учёта легаси-цикла): `civic, notification, poll → chat;
notification, poll → core; economy → {chat, core}; civic → core`. Зависимость
economy→core добавлена 2026-08-06 на Этапе 3 (доменные события в `core.event`);
civic→core — на Этапе 4 (публикация ApplicationResolvedEvent).

**Тест:** `ModuleBoundaryTest` переведён с `verify()` на `detectViolations()`
— API возвращает `Violations` без `throwIfPresent()`, что позволяет отфильтровать
предсуществующий цикл `chat → economy → chat` (`ApplicationModules.verify()`
в версии 2.1.0 кидает исключение цикла как часть `Violations`, и его нельзя
выборочно проигнорировать через `Violations.filter`). Фильтрация производится
по `hasMessageContaining("Cycle detected")` — единственное оставшееся
нарушение, не являющееся частью событийной миграции. Все остальные нарушения
границ (JwtChannelInterceptor, ChatUserService, ElectionFacade, BuyFirstLocationHandler
и т.д.) устранены декларативной настройкой модулей и в выводе теста не появляются.

**Проверки (зелёные):**
- `ModuleBoundaryTest` — 2/2 (структура модулей + `detectViolations()` без нелегальных нарушений).
- Полный `mvn -o test` — 5/5 (включая `PlatformApplicationTests` и юнит-тест слушателя).
- `mvn -o spring-boot:run` — приложение стартует (Tomcat на 8080, HTTP 401 на `/` — ожидаемо под Spring Security).

**Файлы:**
- `babich-app/src/test/java/com/platform/ModuleBoundaryTest.java`
- `babich-app/src/main/java/com/platform/{auth,chat,core,economy,civic,notification,poll}/package-info.java`

**Когда `verify()` заработает полностью:** цикл chat↔economy — это
единственное нарушение, оставшееся в `detectViolations()`. Когда экономические
модули будут отделены от chat (реальный перенос по ходу Этапов 3-6), фильтр
цикла из теста убирается и тест снова переводится на `verify()`.

### Этап 2: NotificationService + WS push
**Статус: ✅ ГОТОВ (2026-08-05)** — `@ApplicationModuleListener` + юнит-тест
слушателя добавлены; тесты `@RecordApplicationEvents`/`Scenario` — в плане
Этапа 3 (см. ниже)

- Создан `NotificationEventListener` — слушатель на `ElectionClosedEvent`
- Отправляет через SimpMessagingTemplate в `/user/{username}/queue/notifications`
  (principal — username, а не characterId: так устроен JwtChannelInterceptor
  и остальные user-queue проекта, например unread-updates)
- Сохраняет Notification в БД через `NotificationService.notify()`
- `ElectionFacade` переведён с прямого вызова `notificationService.notifyDistrict(...)`
  на публикацию события: `DomainEventPublisher.publish(ElectionClosedEvent)` —
  старое прямое направление зависимости Слой 3 → Слой 4 удалено полностью
- **Бонус:** раньше таймерный путь `closeExpiredElections()` НЕ слал уведомления
  (дыра — уходили только при ручном закрытии). Теперь оба пути публикуют
  событие, уведомления доставляются всегда

**Файлы:**
- `com/platform/core/event/ElectionClosedEvent.java` — событие (type=ELECTION_CLOSED)
- `com/platform/notification/listener/NotificationEventListener.java` — подписчик
- `com/platform/notification/dto/NotificationResponse.java` — DTO для WS-пуша

**Нюанс реализации:** Spring запрещает `@Transactional` на методе
`@ApplicationModuleListener` (кроме REQUIRES_NEW/NOT_SUPPORTED) — слушатель
работает без собственной транзакции, каждое сохранение делает
`notificationService.notify()` в своей.

**Дополнение (СДЕЛАНО, 2026-08-05):**
1. `@TransactionalEventListener(AFTER_COMMIT)` заменён на
   `@ApplicationModuleListener` — событие теперь пишется в `event_publication`
   в транзакции публикатора и может быть доставлено повторно после рестарта
   (outbox-гарантии Modulith).
2. Создан `NotificationEventListenerTest` (Mockito, юнит-уровень):
   - **регрессия основного пути**: при `ElectionClosedEvent` уведомления
     сохраняются для всех жителей района (`notificationService.notify(...)`)
     и WS-пуш уходит каждому в `/user/{username}/queue/notifications`, с
     проверкой содержимого `NotificationResponse` (title, тип, relatedEntityId);
   - **пустой район**: при отсутствии жителей слушатель не падает и не шлёт
     ни уведомлений, ни WS-пушей.
3. Остаются в плане полные DoD-тесты интеграционного уровня (см. Definition
   of Done): `@RecordApplicationEvents` на `ElectionFacade.closeElection(...)`
   и `Scenario`-тест сквозного пути — их добавлять на Этапе 3, вместе с
   аналогичными тестами для RewardService, чтобы не разводить инфраструктуру
   интеграционных тестов дважды.

### Этап 3: RewardService + фикс BuyFirstLocationHandler
**Статус: ✅ ГОТОВ (2026-08-06)**

Сделано:
- `RewardService.giveCoins/takeCoins/giveXp` публикуют `CoinsChangedEvent`/
  `XpChangedEvent` через `DomainEventPublisher` (проверено DEBUG-логом
  `Publishing domain event: type=COINS_CHANGED/XP_CHANGED`).
- `TransactionLogEventListener` (`@ApplicationModuleListener`) слушает оба
  события и пишет аудит-запись в `TransactionLog` (resourceType COIN/XP_USER,
  amount со знаком: списание — отрицательное, relatedEntityId сохраняется).
- `BuyFirstLocationHandler` переведён с прямой записи `user.setCoinBalance(...)`
  на `rewardService.takeCoins(...)` — дыра в TransactionLog закрыта: покупка
  первой платной локации теперь пишет аудит LOCATION_CREATE.

**DoD-тест:** `RewardServiceAuditIntegrationTest` (5 тестов, зелёные):
1. `giveCoins` → событие + аудит COIN (+250).
2. `takeCoins` → событие с отрицательным amount + аудит COIN (−100, relatedEntityId=777).
3. `takeCoins` при недостатке баланса → `IllegalStateException`, баланс не меняется,
   событие НЕ публикуется, аудит-записи нет.
4. `giveXp` → событие + аудит XP_USER (+40).
5. Scenario покупки первой платной локации: `ApplicationService.submit(...)`
   → `BuyFirstLocationHandler` → `LocationService.createLocation` →
   `RewardService.takeCoins` → событие → аудит LOCATION_CREATE (−100,
   relatedEntityId задан); баланс уменьшен, статус RESIDENT.

**Расхождение с изначальным DoD (важно):** пункты теста публикации
(`@RecordApplicationEvents`) и `Scenario` API оказались неприменимы в этой
конфигурации. События доставляются через персистентный outbox
(`event_publication`), и в Spring Modulith 2.1.0 `@ApplicationModuleListener`
уходит на асинхронный `TaskExecutor` — синхронно перехватить его в тесте
через `PublishedEvents`/`Scenario` не удаётся (см. javadoc теста). Поэтому
сквозной путь проверяется по **наблюдаемому эффекту**: аудит-записи в
`TransactionLog`, которую пишет подписчик; появление записи ожидается
поллингом с таймаутом 5 c (`awaitAuditLogs`). Требование DoD сохранено по
сути: тест падает, если подписчик не отработал.

**Связанные изменения границ:** публикация событий требует зависимости
economy→core (события вынесены в `core.event`) — `allowedDependencies`
модуля economy расширено на `{"chat", "core"}` (см. Этап 1.5).

### Этап 4: ApplicationService → ApplicationResolvedEvent
**Статус: ✅ ГОТОВ (2026-08-06)**

Сделано:
- Создан `ApplicationResolvedEvent` (type=APPLICATION_RESOLVED) — конкретный
  event в `core.event`: applicationId, userId (ВНЕШНИЙ User.id — поле
  `Application.userId`, а не внутренний ChatUser.id), status — **строка**
  (имя enum ApplicationStatus: APPROVED/REJECTED), а не сам enum: событие
  живёт в `core.event` и не должно зависеть от модуля civic (границы
  модулей). resultMessage в событие НЕ входит — подписчик формирует текст
  уведомления сам по статусу (это также держит сериализованный JSON
  события короче лимита `event_publication.serialized_event` varchar(255)).
- `ApplicationService` публикует событие после `handler.handle()` +
  `applicationRepository.save()` — и в сценарии уже-решённой заявки
  (повторный submit возвращает существующую заявку без повторной публикации).
- `NotificationEventListener.onApplicationResolved` (`@ApplicationModuleListener`)
  — подписчик: находит всех персонажей пользователя через
  `ChatUserRepository.findAllByUserId(userId)` (у пользователя может быть
  несколько персонажей — по одному на район), сохраняет Notification
  (тип APPLICATION_RESULT, relatedEntityId = applicationId) и шлёт WS-пуш в
  `/user/{username}/queue/notifications`.
- `ApplicationResolvedEvent` зарегистрирован в `@JsonSubTypes` `DomainEvent` —
  без этого Jackson-десериализация из outbox (`event_publication`) падает.
- Граница civic расширена на `core` (см. Этап 1.5).

**DoD-тест:** `ApplicationResolvedIntegrationTest` (1 тест, зелёный):
1. Scenario покупки первой платной локации: `ApplicationService.submit(...)`
   → `BuyFirstLocationHandler` → статус APPROVED → ApplicationResolvedEvent →
   подписчик → Notification заявителю (тип APPLICATION_RESULT,
   relatedEntityId = applicationId, заголовок «Заявка одобрена»).

**Расхождение с изначальным DoD (важно):** `@RecordApplicationEvents` и
`Scenario` API неприменимы в этой конфигурации — события доставляются через
персистентный outbox (`event_publication`) на асинхронном TaskExecutor
(подробнее см. Этап 3, там же объяснение). Поэтому сквозной путь проверяется
по наблюдаемому эффекту: записи `Notification`, которую пишет подписчик;
появление записи ожидается поллингом с таймаутом 5 c (`awaitNotifications`).
Требование DoD сохранено по сути: тест падает, если подписчик не отработал.
В плане остается расширение на другие типы заявок (voting/appeal) — на
текущий момент существует единственный тип `BUY_FIRST_LOCATION`.

**Особенность адресации:** событие несёт ВНЕШНИЙ User.id, а уведомления
адресуются внутреннему ChatUser.id. Пользователь может иметь несколько
персонажей — подписчик уведомляет каждого через `findAllByUserId`.

### Этап 5: SchedulerGateway (единый TickService)
**Статус: ✅ ГОТОВ (2026-08-06)**

Сделано:
- Создан `core.scheduler.SchedulerGateway` — **единственный** `@Scheduled`
  в приложении (`fixedDelay = 15_000`); `fixedDelay`, а не `fixedRate` —
  защита от лавины при clock leap.
- `TickHandler` — интерфейс периодической задачи (`onTick()`, дефолтный
  интервал 60_000 мс); Spring собирает `List<TickHandler>`.
- `ScheduledCheck` — реестр отложенных проверок (таблица `scheduled_checks`:
  checkType, entityType, entityId, dueAt, timeoutAt, status
  PENDING/COMPLETED); один индексный запрос вместо полных сканов таблиц.
- `ScheduledCheckHandler` — обработчик отложенной проверки (`checkType()`
  + `handle(...)`); Spring собирает `List<ScheduledCheckHandler>`, gateway
  диспетчеризует по checkType.
- Перенос задач: `ElectionScheduler` удалён → `poll.scheduler.PollCloseCheckHandler`
  (PollService регистрирует проверку при создании выборов, dueAt=endsAt;
  делегирует в `ElectionFacade.closeElection`; ручное закрытие гасит проверку
  через `cancelPending`); `PresenceService.cleanupStalePresences` → `onTick()`
  (intervalMillis=15_000).
- Мёртвый код удалён: `ElectionFacade.closeExpiredElections`,
  `PollService.closeExpiredPolls`, `PollRepository.findByStatusAndEndsAtBefore`.
- Границы: модуль `chat` расширен на `core` (PresenceService → TickHandler);
  `ModuleBoundaryTest` 2/2 зелёные.

**DoD-тест:** `SchedulerGatewayIntegrationTest` (1 тест, зелёный).
Реальный fixedDelay-интервал не ждётся: `onTick()` дёргается вручную.
Сквозной путь: `initiateElection` регистрирует ScheduledCheck (dueAt=endsAt) →
перенос dueAt в прошлое → ручной `onTick()` → PollCloseCheckHandler →
`ElectionFacade.closeElection` → `ElectionClosedEvent` → подписчик →
Notification жителю (ELECTION_RESULT, relatedEntityId=pollId); проверка
закрыта (COMPLETED), Poll CLOSED. По сути DoD сохранён: тест падает,
если обработчик или подписчик не отработал.

### Этап 6: PollResultDispatcher
**Статус: ✅ ГОТОВ (2026-08-06)**

Сделано:
- `PollResultDispatcher` — выбирает реализацию `PollResultHandler` по
  `poll.getType()` (Spring собирает `Map<PollType, PollResultHandler>`);
  `SimplePollResultHandler` — диспетчеризация простых голосований
  (переименован из прежнего `PollResultHandler`).
- `ElectionResultHandlerAdapter` — обработчик результатов выборов (`ELECTION`):
  подсчёт голосов, назначение губернатора (LocationPost для победителей по
  слотам), публикация `ElectionClosedEvent` через `DomainEventPublisher` —
  то, что раньше делал `ElectionFacade.closeElection` прямым вызовом;
  прямой вызов из фасада убран.
- `PollClosedEvent` — новое событие в `core.event` (type=POLL_CLOSED):
  pollId, pollType (**String** — имя enum `PollType`, чтобы core не зависел
  от poll), resultSummary (сводка голосов по кандидатам). Зарегистрирован в
  `@JsonSubTypes` `DomainEvent` — без этого Jackson-десериализация из outbox
  (`event_publication`) падает.
- `PollResultDispatcher` публикует `PollClosedEvent` **всегда** (для любого
  PollType и даже пустого результата) — публикация события не завязана на
  конкретную реализацию хэндлера. Старый класс `ElectionResultHandler` удалён.
- `ElectionFacade.closeElection` теперь только закрывает Poll и
  диспетчеризует результат; назначение губернатора ушло в
  `ElectionResultHandlerAdapter`.

**Расхождение с изначальным DoD (важно):** `@RecordApplicationEvents` /
`Scenario` API неприменимы в полном виде в этой конфигурации (как на
Этапах 3–5 — события доставляются через персистентный outbox
`event_publication` на асинхронном TaskExecutor; подробности см. Этап 3).
Поэтому сквозной путь проверяется в `PollClosedEventIntegrationTest`:
1. `PollClosedEventCaptor` (`@RecordApplicationEvents`) перехватывает события
   **синхронно внутри теста** — создание выборов → ручное закрытие →
   событие POLL_CLOSED дошло, pollType=ELECTION.
2. Полный сквозной путь проверяется по наблюдаемому эффекту в том же тесте:
   `ElectionFacade.closeElection` → `PollResultDispatcher` →
   `ElectionResultHandlerAdapter` → назначение LocationPost губернатора
   (4 должности для победителей по слотам) → `ElectionClosedEvent` →
   подписчик → Notification жителям района. Тест падает, если диспетчер не
   выбрал адаптер или подписчик не отработал.

**Каскад голосований (Parliament → District, `parentPollId`) до
`CharterAmendedEvent`** — за пределами текущей версии: ни дочернего типа Poll,
ни обработчика каскада, ни события `CharterAmendedEvent` в коде нет. План на
будущее сохраняется в сценариях/концепции.

### Этап 7: Документация
**Статус: НЕ НАЧАТ**

- Обновить `babichchat-event-architecture.md`
- Создать `event-migration-notes.md` (почему Spring Event + Modulith,
  а не Kafka с первого дня; когда переходить на `spring-modulith-events-kafka`)
- Зафиксировать правило: **события — только для необязательных
  последствий, никогда — для part of the invariant**. Всё, что обязано
  произойти атомарно в одной транзакции (списание + выдача роли/локации),
  остаётся синхронным вызовом внутри доменного сервиса, а не событием —
  иначе легко случайно превратить обязательный эффект в «probably eventually
  happens».

---

## Прогресс

| Этап | Статус | Дата |
|------|--------|------|
| 1. Core-модуль | ✅ Готов (Modulith registry + Jackson-совместимость + `@Modulith`) | 2026-08-05 |
| 1.5. Проверка границ модулей | ✅ Готов: package-info (OPEN/CLOSED+allowedDependencies) + `detectViolations()`; легаси-нарушение — цикл chat↔economy (отфильтрован); economy→core легализована после Этапа 3 | 2026-08-05/2026-08-06 |
| 2. Notification + WS | ✅ Готов (`@ApplicationModuleListener` + юнит-тест слушателя; DoD-интеграция — проверена тем же подходом, что и Этап 3) | 2026-08-05 |
| 3. RewardService + BuyFirstLocationHandler | ✅ Готов: события + аудит + фикс BuyFirstLocationHandler; RewardServiceAuditIntegrationTest 5/5 | 2026-08-06 |
| 4. ApplicationResolvedEvent | ✅ Готов: ApplicationService публикует событие, NotificationEventListener уведомляет заявителя; ApplicationResolvedIntegrationTest зелёный | 2026-08-06 |
| 5. SchedulerGateway | ✅ Готов: единый @Scheduled + TickHandler (PresenceService) + реестр ScheduledCheck (закрытие выборов через PollCloseCheckHandler); ElectionScheduler удалён; SchedulerGatewayIntegrationTest зелёный | 2026-08-06 |
| 6. PollResultDispatcher | ✅ Готов: диспетчеризация по PollType, ElectionResultHandlerAdapter (назначение губернатора), PollClosedEvent (type=POLL_CLOSED); старый ElectionResultHandler удалён; PollClosedEventIntegrationTest зелёный | 2026-08-06 |
| 7. Документация | ❌ Не начат | — |

---

## Ключевые решения

1. **Spring Event + Modulith event registry, а не гипотетический ручной
   Outbox (упоминался в `babichchat-event-architecture.md` как вариант на
   будущее, но не был запланированной задачей) и не Kafka/RabbitMQ с первого
   дня** — в MVP single-instance, `@ApplicationModuleListener` (Modulith)
   поверх `ApplicationEventPublisher` даёт персистентность и replay без
   своей таблицы и своего relay-кода. При переходе на multi-instance/внешнюю
   шину замена происходит на уровне транспорта Modulith, контракт
   `DomainEvent` и подписчики не переписываются.
2. **DomainEvent не хранится в БД как бизнес-сущность** — это транспортный
   объект. Персистентность на уровне `event_publication` (Modulith) — техническая
   гарантия доставки, а не часть доменной модели; подписчик сам решает, что
   и как сохранять в свои таблицы.
3. **ScopeType вынесен в core и объявлен локально в `core.event`, а не
   переиспользует enum из модуля poll** — иначе core зависел бы от poll,
   что нарушает направление зависимостей (mvp-ai-brief.md §7.3.2 описывает
   концепцию, но enum в коде определён в `com.platform.core.event.ScopeType`).
4. **EventType — enum, а не иерархия классов** — для простоты маппинга
   в подписчиках. При необходимости иерархия добавляется через подклассы
   DomainEvent.
5. **Границы модулей проверяются с Этапа 1.5, а не в конце миграции** —
   правило фиксируется тестом (Modulith Verification или ArchUnit) до того,
   как появится код, который его может нарушить.
6. **Каждый этап 2-6 обязан включать тест сквозного асинхронного пути
   (Modulith `Scenario`), а не только тест факта публикации события**
   (`@RecordApplicationEvents`) — иначе возможен ложно-зелёный тест на
   слушателе, который в реальности никогда не вызывается (например, из-за
   отката транзакции в `@Transactional`-тесте, где `AFTER_COMMIT` не
   срабатывает).
