# Статус проекта BabichChat

## Последнее обновление
2026-09-11 (Зафиксирован целевой масштаб: онлайн 100k+ (Telegram-уровень), десктоп + будущая мобилька. Принято решение: путь к 100k+ — внешний STOMP-брокер (RabbitMQ/Artemis через StompBrokerRelay) + presence/unread в Redis, а НЕ ранний переход на WebFlux. Новая заметка architecture/realtime/scale-targets-and-redis.md; контейнер redis добавлен в docker-compose — этап R1)
2026-09-02 (Настройки района перенесены в пер-районные БД-настройки + админская панель «Настройки района» на UI: группы «Выборы губернатора» и «Обжалование»; длительность/окно «живого»/кворум/число слотов выборов больше не захардкожены в коде)

## Сводка прогресса

### MVP (Минимально жизнеспособный продукт)

| Модуль | Статус | Примечания |
|--------|--------|------------|
| Аутентификация (JWT) | ✅ Завершено | Регистрация, логин, JWT-токены |
| Районы (Districts) | ✅ Завершено | Дефолтный район "Центральный" создаётся при старте |
| Системные локации | ✅ Завершено | 8 системных локаций с комнатами, единая модель Location (isSystem + type) |
| Персонажи (ChatUser) | ✅ Завершено | Независимая сущность (не extends User), привязка к району, уникальность имени в районе |
| Создание персонажа | ✅ Завершено | Форма создания через CharacterCreateComponent |
| Выбор района (DistrictSelect) | ✅ Завершено | Проверка персонажа, профиль, вход |
| Чат (комнаты) | ✅ Завершено | WebSocket-чаты в комнатах локаций |
| Экономика (тап-фарм) | ✅ Завершено | Работа дворником, монеты, энергия |
| Покупка первого жилья (аудит) | ✅ Завершено | BuyFirstLocationHandler переведён на RewardService.takeCoins — покупка пишет аудит TransactionLog (LOCATION_CREATE) |
| Покупка первого жилья | ✅ Завершено | Заявка в мэрию, проверка HOMELESS, создание Location |
| LocationPost (должности) | ✅ Завершено | Таблица location_posts, enum LocationPostType, сервис, контроллер |
| Авто-членство в системных локациях | ✅ Завершено | При создании персонажа — автоматическое добавление location_members для всех isSystem=true локаций района |

### Сценарии

| Сценарий | Статус |
|----------|--------|
| №1. Первый вход в дефолтный район | ✅ Реализован |
| №1.1. Создание персонажа | ✅ Реализован |
| №1.2. Удаление персонажа из района | ❌ Не реализован |
| №2. Первые выборы | ✅ Реализован (backend + frontend) |

### Технические задачи

| Задача | Статус |
|--------|--------|
| ChatUser — независимая entity (not extends User) | ✅ Выполнено |
| ChatUser.username — копия User.username для WS | ✅ Выполнено |
| district_id + unique(user_id, district_id) | ✅ Выполнено |
| unique(character_name, district_id) | ✅ Выполнено |
| Location.owner → ChatUser (не User) | ✅ Выполнено |
| LocationMember.character → ChatUser | ✅ Выполнено |
| BuyFirstLocationHandler — поиск по userId | ✅ Выполнено |
| WorkController — работает через chatUser.getId() | ✅ Выполнено |
| DB migration (init-chat-user-district.sql) | ✅ Выполнено |
| LocationPost entity + enum + repo + service + controller | ✅ Выполнено |
| Авто-членство в системных локациях | ✅ Выполнено |
| DB migration (add-location-posts.sql) | ✅ Выполнено |
| Актуализация документации (districts-and-public-locations.md) | ✅ Выполнено |
| Четырёхслойная архитектура: Entity → Facade → Service → Handler | ✅ Выполнено (election) |
| ElectionScheduler — @Scheduled(fixedRate=60s) | ✅ Выполнено |
| Campaign + CampaignContribution entity/service | ✅ Выполнено |
| Notification + NotificationService (рассылка по району) | ✅ Выполнено |
| PersonLevel (гейт уровня 3 для старта выборов) | ✅ Выполнено |
| PollVoteRepository — countVotesPerCandidate, sumVoteWeightByPollId | ✅ Выполнено |
| Кворум от живых участников района (50%) | ✅ Выполнено |
| Core-модуль событийной архитектуры (DomainEvent, EventType, ScopeType, DomainEventPublisher) | ✅ Выполнено |
| ElectionClosedEvent + NotificationEventListener (@TransactionalEventListener AFTER_COMMIT) | ✅ Выполнено |
| ElectionFacade → публикация события вместо прямого вызова NotificationService (Слой 3 → Слой 4 убран) | ✅ Выполнено |
| NotificationResponse DTO для WS-пуша /user/{username}/queue/notifications | ✅ Выполнено |
| Уведомления при автозакрытии выборов по таймеру (раньше — дыра, слались только при ручном закрытии) | ✅ Выполнено |
| RewardService публикует CoinsChangedEvent/XpChangedEvent | ✅ Выполнено |
| TransactionLogEventListener (@ApplicationModuleListener) — аудит COIN/XP_USER в TransactionLog | ✅ Выполнено |
| BuyFirstLocationHandler → RewardService.takeCoins (закрыта дыра в TransactionLog) | ✅ Выполнено |
| RewardServiceAuditIntegrationTest (DoD Этапа 3, 5 тестов: giveCoins/takeCoins/overdraw/giveXp/покупка локации) | ✅ Выполнено |
| Граница economy→core легализована (package-info, allowedDependencies = {chat, core}) | ✅ Выполнено |
| ApplicationResolvedEvent (тип APPLICATION_RESOLVED) + регистрация в @JsonSubTypes DomainEvent | ✅ Выполнено |
| ApplicationService публикует ApplicationResolvedEvent после разрешения заявки (handler.handle() + save) | ✅ Выполнено |
| NotificationEventListener.onApplicationResolved (@ApplicationModuleListener) — уведомление заявителя (Notification + WS-пуш) | ✅ Выполнено |
| ApplicationResolvedIntegrationTest (DoD Этапа 4, сквозной путь: submit → событие → подписчик → Notification) | ✅ Выполнено |
| Граница civic→core легализована (package-info, allowedDependencies = {chat, core}) | ✅ Выполнено |
| SchedulerGateway — единый @Scheduled (core.scheduler: TickHandler, ScheduledCheck, ScheduledCheckHandler, ScheduledCheckService, SchedulerGateway) | ✅ Выполнено |
| ElectionScheduler удалён → PollCloseCheckHandler (реестр ScheduledCheck, dueAt=endsAt, делегирует в ElectionFacade.closeElection) | ✅ Выполнено |
| PresenceService переведён на TickHandler (onTick, intervalMillis=15_000) | ✅ Выполнено |
| Мёртвый код удалён: closeExpiredElections, closeExpiredPolls, findByStatusAndEndsAtBefore | ✅ Выполнено |
| Граница chat→core легализована (package-info, PresenceService → TickHandler) | ✅ Выполнено |
| SchedulerGatewayIntegrationTest (DoD Этапа 5, сквозной путь: ScheduledCheck → onTick → PollCloseCheckHandler → ElectionClosedEvent → Notification) | ✅ Выполнено |
| PollResultDispatcher — выбор PollResultHandler по PollType (Map, собранная Spring'ом) | ✅ Выполнено |
| PollResultHandler → SimplePollResultHandler (переименован) | ✅ Выполнено |
| ElectionResultHandlerAdapter — назначение губернатора (LocationPost победителям по слотам) + публикация ElectionClosedEvent; прямой вызов из ElectionFacade убран | ✅ Выполнено |
| PollClosedEvent (type=POLL_CLOSED, pollType String, resultSummary) в core.event + регистрация в @JsonSubTypes DomainEvent | ✅ Выполнено |
| PollResultDispatcher публикует PollClosedEvent всегда (независимо от реализации хэндлера) | ✅ Выполнено |
| ElectionResultHandler удалён | ✅ Выполнено |
| PollClosedEventIntegrationTest (DoD Этапа 6, сквозной путь: closeElection → dispatcher → adapter → LocationPost → ElectionClosedEvent → Notification; PollClosedEventCaptor перехватывает событие) | ✅ Выполнено |
| Полный mvn test — 13/13 зелёные | ✅ Выполнено |
| ElectionStartedEvent (type=ELECTION_STARTED) в core.event + регистрация в @JsonSubTypes DomainEvent; публикация из ElectionFacade.initiateElection | ✅ Выполнено |
| NotificationEventListener.onElectionStarted — рассылка «выборы начались» жителям района + WS-пуш (notificationType=ELECTION_STARTED) | ✅ Выполнено |
| Гейт «нет губернатора» (LocationPost GOVERNOR в мэрии) + запрет параллельных выборов — проверка в PollService.createGovernorElection, 400 с текстом | ✅ Выполнено |
| NotificationController (REST /api/notifications): история, unread-count, read/accept/decline | ✅ Выполнено |
| LocationPostController/by-location → LocationPostView с именем персонажа (для модалки мэрии) | ✅ Выполнено |
| ElectionController переведён на внутренний ChatUser.id (единый characterId с ElectionResultHandlerAdapter) | ✅ Выполнено |
| GET /api/elections/district/{districtId}/overview → DistrictElectionView (поллинг для мини-таблицы) | ✅ Выполнено |
| Frontend: chat-area «⚡ Действия» → выдвижение кандидатуры (ConfirmModal) на Площади Ленина/Площадь | ✅ Выполнено |
| Frontend: мини-таблица выборов shared/components/election-table (слоты, таймер, голосование, результат) | ✅ Выполнено |
| Frontend: модалка уведомлений — история REST + live WS, типы ELECTION_STARTED/ELECTION_RESULT/APPLICATION_RESULT | ✅ Выполнено |
| Frontend: модалка района «Мэрия» — реальные губернатор/мэр/депутаты из LocationPost | ✅ Выполнено |
| DistrictSettings entity + DistrictSettingsService + DistrictSettingsController (GET/PUT /api/districts/{id}/settings) — пер-районные настройки | ✅ Выполнено |
| Магия выборов убрана: длительность, окно «живого», кворум, число слотов берутся из настроек района (PollService, ElectionFacade) | ✅ Выполнено |
| Frontend: админская панель «Настройки района» (nav-rail → DistrictSettingsModal) с группами «Выборы губернатора» и «Обжалование» | ✅ Выполнено |
| ElectionResultHandlerAdapter назначает победителя ТОЛЬКО на GOVERNOR (мэрия); убран баг «победитель получал POLICE_OFFICER/BANK_DIRECTOR/REAL_ESTATE_DIRECTOR» | ✅ Выполнено |
| DistrictSettingsController ограничен ролями ADMIN/MODERATOR (403 иначе); вкладка «Настройки района» в nav-rail скрыта для остальных | ✅ Выполнено |
| Аккаунт username=joks автоматически получает роль ADMIN (при создании персонажа) | ✅ Выполнено |
| ChatUserController: список персонажей района + смена роли (только ADMIN, свою роль менять нельзя) | ✅ Выполнено |
| Frontend: shared DistrictUsersTable (поиск по персонажу/аккаунту, дропдаун роли, сохранение) + вкладка «Персонажи района» в DistrictSettingsModal для ADMIN | ✅ Выполнено |
| DistrictUsersTable стала универсальной: редактирование полей chat_users (роль, профессия, статус, монеты, энергия, рейтинг); роль можно менять, кроме «последнего админа района» | ✅ Выполнено |
| MessageService + <app-toast/>: всплывающие уведомления в правом верхнем углу («Успешно сохранено»/«Ошибка сохранения») | ✅ Выполнено |
| Зафиксирован целевой масштаб 100k+ онлайн; путь — внешний STOMP-брокер (RabbitMQ/Artemis через StompBrokerRelay) + presence/unread в Redis, WebFlux — опциональный поздний этап (заметка architecture/realtime/scale-targets-and-redis.md, этапы R1–R5) | ✅ Зафиксировано |
| R1: контейнер redis в docker-compose.yml | ✅ Выполнено |
| R2: STOMP Broker Relay (RabbitMQ/Artemis) вместо SimpleBroker | ❌ Не начат |
| R3: Presence/online-счётчики/unread → Redis | ❌ Не начат |
| R4: прод-конфиг (show-sql, ddl-auto → миграции, пул HikariCP, индексы) | ❌ Не начат |
