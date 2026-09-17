# Системная модель — карта кода BabichChat

> Файл про **факты**: что реально есть в коде (babich-app, Spring Boot) и где искать.
> Написан по коду на момент коммита `7621efe`. При изменении сущностей/модулей — актуализировать.
> Намерение и игровые механики — в [`vision/concept.md`](../vision/concept.md).

## Структура backend

```
com/platform/
├── auth/          # User, JWT, Spring Security (не игровая логика)
└── chat/
    ├── config/            # WebSocketConfig, JwtChannelInterceptor, DataInitializer
    ├── controller/        # REST: chatUser, district, location, message, webSocket
    ├── entity/            # ChatUser, District, Location, LocationUser, Room,
    │                      # Message, RoomReadStatus, CharacterPresence, Gang,
    │                      # DistrictSettings, Notification(в modules)
    ├── enums/             # CivicRole, ChatRole, PublicLocationType, LocationCategoryType,
    │                      # SystemRoleType, PersonLevel, LocationUserRole, MessageType...
    ├── core/
    │   ├── event/         # DomainEvent, DomainEventPublisher, EventType, ScopeType
    │   │                  # (см. architecture/event/)
    │   └── scheduler/     # SchedulerGateway (единственный @Scheduled), TickHandler,
    │                      # ScheduledCheck/ScheduledCheckHandler (отложенные задачи)
    ├── modules/
    │   ├── application/   # Заявки: Application, ApplicationType (BUY_FIRST_LOCATION,
    │   │                  # REGISTER_PASSPORT, REGISTER_WORK_LICENCE), стратегия
    │   │                  # ApplicationHandler (BuyFirstLocationHandler, RegisterPassport,
    │   │                  # RegisterWorkLicence)
    │   ├── economy/       # RewardService, EnergyService, WorkService (тап-фарм),
    │   │                  # TransactionLog + listener, RewardReason, Profession
    │   ├── notification/  # Notification entity/REST, listeners (WS-пуш),
    │   │                  # CharacterUpdatedListener
    │   └── poll/          # Голосования/выборы: Poll, PollCandidate, PollVote,
    │                      # ElectionFacade, PollService, PollResultHandler +
    │                      # ElectionResultHandlerAdapter, PollCloseCheckHandler
    ├── repository/        # JPA-репозитории по папкам
    └── service/           # ChatUserService, DistrictService, LocationService,
                           # LocationUsersService, MessageService, UnreadService,
                           # PresenceService, PersonLevelService (service/level/)
```

## Ключевые факты по персонажу и экономике

- **ChatUser** (персонаж, один на район у User) несёт: `coinBalance`, `xpUser`,
  `xpGang`, `energy` + `energyLastUpdated`, `gameStatus` (по умолчанию HOMELESS),
  `profession` (enum, по умолчанию DVORNIK), `civicRole` (enum CivicRole:
  DEPATY, DIRECTOR, HIRED_WORKER, UNEMPLOYED, POLICEMAN, BUSINESSMAN, CONVICTED),
  `passportId`, `workLicenceId`, `districtId`.
- **Экономика**: все начисления через `RewardService` (coins/xp, reason-enum
  `RewardReason`) → событие `CoinsChangedEvent`/`XpChangedEvent` →
  `TransactionLogEventListener` пишет аудит в `TransactionLog`.
  Отдельных сущностей CoinBalance/Energy нет — поля на ChatUser.
- **Энергия**: `EnergyService`, вычисление регенерации от `energyLastUpdated`.
  Redis пока не подключён (план — см. architecture/realtime/scale-targets-and-redis.md).
- **Уровень**: `PersonLevel` — enum с XP-порогами (`PersonLevel.fromXp`),
  сервис `PersonLevelService` (гейты: `hasMinLevel`, порог следующего уровня для UI).
  Отдельной таблицы уровней нет.
- **Заявки**: `Application` + стратегия `ApplicationHandler` по `ApplicationType`;
  решение принимает сотрудник мэрии (модерация), не автоодобрение.
  При resolve публикуются `ApplicationResolvedEvent` и `CharacterUpdatedEvent`.
- **Выборы**: `ElectionFacade` → `PollService` → по истечении `endsAt`
  `PollCloseCheckHandler` (через SchedulerGateway) → `PollResultDispatcher` →
  `ElectionResultHandlerAdapter` назначает GOVERNOR (member с systemRole = GOVERNOR + MODERATOR) в мэрии.
  Настройки выборов — в `district_settings` (DistrictSettings).

## Что из концепции ещё НЕ реализовано

Группировки (Gang/GangMember), полиция (PoliceRecord), банк (Deposit),
рынок (MarketStall/StallInventory), Charter, PostRank, квоты, инвентарь,
рынок недвижимости — сущностей в коде нет. Планы — в concept.md и сценариях.

## Приоритет источников истины

1. Код
2. `vision/concept.md` (намерение, пишет человек)
3. Этот файл и `architecture/*` (факты, пишет AI — при расхождении править документ)
