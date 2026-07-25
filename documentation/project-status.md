# BabichChat — статус проекта и roadmap

> Служебный документ для быстрого восстановления контекста между сессиями
> разработки. Отражает **фактическое** состояние кода на текущий момент,
> сверенное с концепцией (`babichchat_concept.md`) и MVP-брифом
> (`babichchat_mvp_ai_brief.md`). Обновляйте этот файл по мере продвижения.

---

## 1. Модульная структура backend (babich-app)

```
com.platform/
├── auth/       — User, JWT-аутентификация (базовый RBAC / systemRole)
├── chat/       — ChatUser, Location, Room, Message, District, PublicLocation (ядро чата)
├── economy/    — TransactionLog, RewardService, EnergyService, WorkService, Profession
└── civic/      — Application (заявки) + ApplicationHandler-стратегии
```

Разделение уже соответствует принципу концепции: игровые модули (роли, экономика,
заявки) — независимые пакеты/таблицы, не единая "универсальная" сущность.

Будущие модули (по мере реализации): `gang/`, `police/` (или `civic/police`),
`bank/`, `market/`.

---

## 2. Что уже реализовано

### 2.1 Chat-ядро (было до экономического слоя)
- `ChatUser extends User` (JOINED inheritance) — характер персонажа
- `Location`, `Room`, `LocationMember`, `LocationTemplate`, `TemplateRoom`
- `Message`, `RoomReadStatus`, `CharacterPresence` (онлайн-трекинг)

### 2.2 Районы и системные локации — ГОТОВО
(см. `documentation/districts-and-public-locations.md` — подробности)

- `District` (code, name, description) ↔ `PublicLocation`
- `PublicLocationType` enum — 8 системных типов:
  `CITY_HALL`, `LENIN_SQUARE`, `POLICE_STATION`, `PRISON`, `BANK`,
  `WAREHOUSE`, `GENERAL_MARKET`, `REAL_ESTATE_MARKET`
- `Room` теперь опционально принадлежит либо `Location`, либо `PublicLocation`
- Автосоздание дефолтного района "Центральный" + 8 системных локаций при старте
- Backend API: `GET /api/districts`, `/api/districts/{id}`,
  `/api/districts/{id}/public-locations`
- Frontend: модели (`district.interface.ts`, `public-location.interface.ts`,
  `public-location-type.enum.ts`), `district.service.ts`, интеграция в sidebar

### 2.3 Экономический слой — ГОТОВО (MVP-уровень)
Поля в `ChatUser`:
- `coinBalance`, `xpUser`
- `energy` + `energyLastUpdated` (пассивное восстановление на лету, без тикающего таймера)
- `gameStatus` (`HOMELESS` / `RESIDENT`)
- `profession` (enum `Profession`: `UNEMPLOYED`, `DVORNIK`)

Сервисы/сущности:
- `TransactionLog` — лог всех начислений/списаний
- `RewardReason` enum — **уже с запасом на будущее**: помимо активных причин
  (`WORK_SHIFT`, `BUY_FIRST_LOCATION`) заведены коды под нереализованные пока
  механики (`GANG_TRIBUTE`, `GANG_TREASURY_INCOME`, `POLICE_FINE`,
  `POLICE_GANG_CATCH`, `BANK_DEPOSIT_OPEN`, `BANK_INTEREST`,
  `BANK_FEE_TO_TREASURY`, `MARKET_STALL_RENT`, `MARKET_SALE`,
  `ESCORT_SESSION`, `THEFT_SUCCESS`) — не нужно будет трогать enum при
  реализации этих модулей
- `RewardService`, `EnergyService`, `WorkService`, `WorkController` — тап-фарм
  дворника полностью реализован (энергия списывается, монеты + XP начисляются,
  всё через `RewardService`)

Frontend: `wallet-widget`, `work-page`, `buy-first-location`,
`application.service.ts`, `work.service.ts`, модели `application.interface.ts`,
`work-result.interface.ts`.

### 2.4 Заявки (civic) — ГОТОВО (базовый уровень)
- `Application` (userId, type, status, payload, resultMessage, createdAt,
  processedAt) — расширяемая структура, готова под будущую замену
  автоодобрения на реальное голосование без переделки модели
- `ApplicationType` enum — пока только `BUY_FIRST_LOCATION`
- `ApplicationHandler` (интерфейс-стратегия) + `BuyFirstLocationHandler`
  (конкретная реализация — по одному классу на тип заявки, паттерн уже задан)
- `ApplicationService`, `ApplicationController`

---

## 3. Сверка с планом MVP (`babichchat_mvp_ai_brief.md`, раздел 6)

| # | Шаг MVP | Статус |
|---|---|---|
| 1 | RewardService + TransactionLog + монеты/XP-USER/энергия | ✅ Готово |
| 2 | Профессия «дворник» (тап-фарм) + статус «бомж» | ✅ Готово |
| 3 | Application → покупка первой локации | ✅ Готово |
| 4 | `Gang`, `GangMember`, `GangHierarchyPost`, `GangLocation` | ❌ Не начато |
| 5 | Группировка «Воры»: `TheftAttempt`, «пойти на дело» | ❌ Не начато |
| 6 | Группировка «Проститутки»: `EscortSession` | ❌ Не начато |
| 7 | `CivicRole` = полицейский участок (штраф/протокол/проверка) | ❌ Не начато |
| 8 | `AppointedRole` = банк (`Deposit`, шедулер процентов) | ❌ Не начато |
| 9 | `BusinessRole` = рынок (`MarketStall`, `StallInventory`, `StallCashbox`) | ❌ Не начато |
| 10 | Заглушка `RealEstateListing` (без бизнес-логики) | ❌ Не начато |

Отдельно, вне основной MVP-цепочки, но уже сделано параллельно и на шаг
впереди графика брифа: **система районов и системных локаций** (раздел 2.2)
— в MVP-брифе про districts почти не сказано, это взято из полной концепции
(разделы 0.1 и 8).

---

## 4. Игровой цикл — что реально проходимо прямо сейчас

```
Регистрация → статус "бомж" (HOMELESS)
      → работает дворником (WorkController: тап-фарм, тратит energy,
        получает coinBalance + xpUser через RewardService)
      → копит монеты → подаёт Application(BUY_FIRST_LOCATION)
        → BuyFirstLocationHandler автоодобряет → покупка первой Location
      → gameStatus меняется на RESIDENT
      → [ДАЛЬШЕ ЦИКЛ ОБРЫВАЕТСЯ — некуда идти: нет группировок, нет структур,
         нет банка/рынка]
```

Именно поэтому следующий шаг — это шаги 4–9 из таблицы выше: без них цикл не
замкнут (жителю после покупки первой локации сейчас нечем заняться дальше).

---

## 5. Рекомендуемый следующий шаг

**Вариант A (по графику брифа): Группировки — шаги 4–6**
Логичнее всего продолжать по своей же дорожной карте:
- Экономический фундамент (`RewardService`/`EnergyService`/`Application`) уже
  заточен под это
- `RewardReason` уже содержит нужные коды (`GANG_TRIBUTE`, `THEFT_SUCCESS`,
  `ESCORT_SESSION`, `GANG_TREASURY_INCOME`) — добавлять в enum ничего не надо
- Это следующее звено цепочки «бомж → дворник → первая локация →
  **группировка/структура**»

План работ:
1. `Gang`, `GangMember`, `GangHierarchyPost`, `GangLocation` — entity + repository
2. `ApplicationType.JOIN_GANG` + `JoinGangHandler` (по аналогии с
   `BuyFirstLocationHandler`)
3. Группировка «Воры»: `TheftAttempt` entity, эндпоинт «пойти на дело», бросок
   с шансом успеха (зависит от `XpGang`), анти-фрод лимит через Redis TTL
4. Группировка «Проститутки»: `EscortSession` entity, механика платной встречи
5. Frontend: страница выбора группировки, экран действий группировки

**Вариант B: Полицейский участок — шаг 7**
Проще (один `civicRole`, три действия: штраф/протокол/проверка на
группировку), и логически завершает пару «воры/проститутки ↔ разоблачение».
Но без группировок ему буквально нечего разоблачать — **вариант A логичнее
делать первым**.

**Вариант C: Банк — шаг 8**
Полностью независим от группировок/полиции, самый изолированный модуль
(`AppointedRole BANK_DIRECTOR`, `Deposit`, шедулер начисления процентов). Можно
делать в любой момент, не блокирует и не блокируется другими модулями.

---

## 6. Открытые архитектурные вопросы на будущее (не блокируют MVP)

- Полноценная мэрия с Парламентом, «Площадью Ленина», каскадным распределением
  энергии между структурами (раздел 8 концепции) — сейчас работает только
  через автоодобрение `Application`, без реального голосования
- Мини-игры, кастомизация персонажа, дневные/недельные квесты — не в этой
  итерации (см. концепцию, разделы 4.3, 4.5, 7.3)
- Рынок недвижимости — только сущность-заглушка, без бизнес-логики
  купли-продажи и комиссии `appointedRole`
- Числовой баланс экономики (конкретные суммы наград, курсы, шансы успеха
  краж и т.д.) — открытый вопрос, см. раздел 11 `babichchat_concept.md`

---

## 7. Как обновлять этот файл

При завершении каждого крупного модуля (группировки, полиция, банк, рынок и
т.д.):
1. Переносите соответствующую строку из раздела 3 в раздел 2 (с кратким
   описанием реализованных сущностей/эндпоинтов)
2. Обновляйте раздел 4 (игровой цикл) — что теперь проходимо дальше
3. Актуализируйте раздел 5 (следующий шаг)
