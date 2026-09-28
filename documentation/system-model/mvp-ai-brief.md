# Системная модель — карта кода BabichChat

> Файл про **факты**: что реально есть в коде (babich-app, Spring Boot) и где искать.
> Написан по коду на момент коммита `7621efe`. При изменении сущностей/модулей — актуализировать.
> Намерение и игровые механики — в [`vision/concept.md`](../vision/concept.md).

## Структура backend

```
com/platform/
├── auth/                       # User, JWT, Spring Security (не игровая логика)
└── chat/
    ├── base/                   # базовые игровые сущности: entity/dto/repository/service
    │   ├── chatUser/           # ChatUser (персонаж), EnergyService, ChatUserService
    │   ├── district/           # District, DistrictSettings
    │   ├── location/           # Location, LocationUser (бывший LocationPost), шаблоны локаций
    │   └── room/               # Room, статусы прочтения
    ├── core/                   # ядро: инфраструктура, общие процессы, контракты
    │   ├── config/             # WebSocketConfig, JwtChannelInterceptor, DataInitializer
    │   └── modules/
    │       ├── application/    # ядро процесса заявки
    │       │                   # (см. architecture/application/application-module-layers.md)
    │       ├── domainEvent/    # ядро событий: DomainEvent, EventType, ScopeType,
    │       │                   # events/ (7 фактов), DomainEventPublisher
    │       │                   # (см. architecture/event/domain-event-module-layers.md)
    │       ├── message/        # сообщения чата: entity/dto/controller/service
    │       ├── notification/   # Notification: хранение + REST
    │       ├── onlineSession/  # онлайн-сессии (presence)
    │       ├── poll/           # Poll/PollCandidate/PollVote, PollResultDispatcher
    │       ├── scheduledCheck/ # SchedulerGateway + ScheduledCheck
    │       ├── transactionLog/ # TransactionLog + enum CoinUpdateReason (аудит)
    │       └── webSocket/      # STOMP-инфраструктура и подписки
    └── modules/                # фичи поверх ядра
        ├── application/        # исполнители заявок (стратегии) + REST мэрии
        ├── coin/               # CoinService — единая точка изменений монет/XP
        ├── domainEvent/        # подписчики на события — Слой 4 «доставка»
        ├── gang/               # Gang/GangMember (задел)
        ├── governorElection/   # ElectionService, ElectionResult + REST выборов
        └── work/               # WorkService (тап-фарм)
```

## Ключевые факты по персонажу и экономике

- **ChatUser** (персонаж, один на район у User) несёт: `coinBalance`, `xpUser`,
  `xpGang`, `energy` + `energyLastUpdated`, `gameStatus` (по умолчанию HOMELESS),
  `profession` (enum, по умолчанию DVORNIK), `civicRole` (enum CivicRole:
  DEPATY, DIRECTOR, HIRED_WORKER, UNEMPLOYED, POLICEMAN, BUSINESSMAN, CONVICTED),
  `passportId`, `workLicenceId`, `districtId`.
- **Экономика**: все начисления через `CoinService` (`giveCoins`/`takeCoins`/`giveXp`,
  reason-enum `CoinUpdateReason` в ядре аудита) → события `CoinsChangedEvent`/
  `XpChangedEvent` из ядра событий → `TransactionLogEventListener` пишет аудит
  в `TransactionLog`. Отдельных сущностей CoinBalance/Energy нет — поля на ChatUser.
- **Энергия**: `EnergyService`, вычисление регенерации от `energyLastUpdated`.
  Redis пока не подключён (план — см. architecture/realtime/scale-targets-and-redis.md).
- **Уровень**: `PersonLevel` — enum с XP-порогами (`PersonLevel.fromXp`),
  сервис `PersonLevelService` (гейты: `hasMinLevel`, порог следующего уровня для UI).
  Отдельной таблицы уровней нет.
- **Заявки**: ядро процесса — `chat.core.modules.application` (`Application`,
  `ApplicationType`, `ApplicationStatus`, порт `ApplicationHandler`, решение
  `ApplicationDecision`, реестр `ApplicationHandlerRegistry`, команды
  `ApplicationService`, чтения `ApplicationQueryService`, DTO `ApplicationSummary`);
  исполнители — `chat.modules.application` (стратегии `RegisterPassport`,
  `RegisterWorkLicence` выдают документ через `ChatUserService`).
  Решение принимает сотрудник мэрии (модерация), не автоодобрение.
  При resolve публикуются `ApplicationResolvedEvent` (ядро) и
  `CharacterUpdatedEvent` (стратегия, через решение) — см.
  architecture/application/application-module-layers.md.
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
