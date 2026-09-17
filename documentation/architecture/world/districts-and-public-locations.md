# Система районов и системных локаций

## Обзор
Реализация системы районов (Districts) и системных локаций (Public Locations) согласно концепции babichchat (разделы 0.1 и 8).

**Важно:** Системные локации — это те же `Location` с флагом `isSystem = true` и заполненным полем `type` (enum `PublicLocationType`). Отдельной сущности `PublicLocation` не существует.

## Архитектура

### Основные сущности

#### 1. District (Район)
- **Назначение**: Административная единица, вмещающая жителей и содержащая системные локации
- **Поля**:
  - `id` — уникальный идентификатор
  - `code` — уникальный код района (например, 'CENTRAL')
  - `name` — название района
  - `description` — описание района
- **Связи**:
  - `systemLocations` — список `Location` с `isSystem = true`
  - `locations` — все локации района (включая пользовательские)

#### 2. Location (Локация) — единая сущность
- **Назначение**: Может быть как пользовательской (созданной из шаблона), так и системной (принадлежит району, создаётся автоматически)
- **Поля**:
  - `id` — уникальный идентификатор
  - `template` — шаблон (только для пользовательских)
  - `owner` — владелец-персонаж (только для пользовательских)
  - `district` — район, к которому относится локация
  - `name` — название локации
  - `description` — описание
  - `isSystem` — флаг: `true` = системная, `false` = пользовательская
  - `type` — `PublicLocationType` (только для `isSystem = true`)
  - `inviteCode` — код приглашения (только для пользовательских)
  - `isPublic` — публичная/приватная (только для пользовательских)
  - `rooms` — список комнат локации
  - `members` — список участников (LocationUser, таблица `location_users`)

#### 3. LocationUser (Членство в локации + должность)
- **Назначение**: Универсальная таблица-мост `ChatUser` ↔ `Location` для обеих категорий локаций (таблица `location_users`)
- **Поля**:
  - `id` — уникальный идентификатор
  - `location` — локация (системная или пользовательская)
  - `character` — персонаж-участник
  - `role` — локальная роль в этой локации: `OWNER`, `MODERATOR`, `MEMBER`
  - `isRegistered` — «прописан» (true у владельца и назначенного модератора)
  - `systemRole` — должность в системной локации (`SystemRoleType`), null = обычный участник
  - `appointedAt` — когда назначен на должность
  - `joinedAt` — когда вступил в локацию
- **Ограничения**:
  - `UNIQUE (location_id, character_id)` — один персонаж = одна запись = максимум одна должность в локации
- Для **пользовательских** локаций: запись создаётся при создании локации (`OWNER`)
  или при вступлении по invite-коду (`MEMBER`)
- Для **системных** локаций: запись создаётся только при назначении на должность — авто-членства нет
  (см. «Членство и должности в системных локациях»)
- Отдельной сущности должности больше нет: прежние `LocationPost` / таблица `location_posts`
  упразднены, должность хранится в `location_users.system_role`

### Типы системных локаций (PublicLocationType)

Согласно концепции (раздел 8), каждый район имеет 8 типов системных локаций:

1. **CITY_HALL** — Мэрия (управление районом)
2. **LENIN_SQUARE** — Площадь Ленина (народные голосования, комната "Тёплые трубы" для бомжей)
3. **POLICE_STATION** — Полицейский участок (база civic_role)
4. **PRISON** — Тюрьма (место содержания нарушителей)
5. **BANK** — Банк (вклады, ипотека)
6. **WAREHOUSE** — Склад (закупка товаров для бизнеса)
7. **GENERAL_MARKET** — Рынок (аналог "Авито", свободная аренда прилавков)
8. **REAL_ESTATE_MARKET** — Рынок недвижимости (купля-продажа локаций)

### Должности системных локаций (SystemRoleType)

Хранятся в `location_users.system_role`; допустимые для типа локации должности —
карта `ALLOWED_ROLES` в `LocationUsersService`.

| Должность | Локация | Слотов | Описание |
|-----------|---------|--------|----------|
| GOVERNOR | CITY_HALL | 1 | Глава администрации района (назначается/избирается) |
| MAYOR | CITY_HALL | 1 | Мэр (назначается) |
| DEPUTY | CITY_HALL | N | Депутат (назначается) |
| POLICE_OFFICER | POLICE_STATION | N | Полицейский (фиксированное число слотов на район) |
| BANK_DIRECTOR | BANK | 1 | Директор банка |
| BANK_EMPLOYEE | BANK | N | Сотрудник банка |
| REAL_ESTATE_DIRECTOR | REAL_ESTATE_MARKET | 1 | Владелец рынка недвижимости |

### Членство и должности в системных локациях

После реформы модели («LocationUser», упразднение `LocationPost`) авто-членства больше нет:

- Персонаж **не** получает записей `location_users` в системных локациях района при входе/создании.
- Member системной локации = держатель должности (`system_role` не null). Запись появляется
  только при назначении на должность (`appointSystemRole`) — в т.ч. при победе на выборах губернатора.
- Писать в системную локацию и видеть сообщения вживую можно и без членства
  (право отправки не требует membership).

Это обеспечивает:
- Unread-рассылка в системной локации уходит только штату (держателям должностей).
- Presence показывает физическое присутствие по `CharacterPresence`, а не по members.
- Системная локация попадает в «мои локации» только если персонаж в ней что-то занимает.
- Единая модель прав (`LocationUser.role`) + отдельное поле должности (`LocationUser.systemRole`).

## База данных

### Таблицы

#### districts
```sql
CREATE TABLE districts (
    id BIGSERIAL PRIMARY KEY,
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT
);
```

#### locations (единая таблица)
```sql
CREATE TABLE locations (
    id BIGSERIAL PRIMARY KEY,
    template_id BIGINT REFERENCES location_templates(id),
    owner_id BIGINT REFERENCES chat_users(id),
    district_id BIGINT NOT NULL REFERENCES districts(id),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    type VARCHAR(30),
    category VARCHAR(20),
    xp_location BIGINT NOT NULL DEFAULT 0,
    gang_id BIGINT,
    invite_code VARCHAR(20) UNIQUE,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP
);
```

#### location_users (членство в локациях, обе категории + должность)
```sql
CREATE TABLE location_users (
    id BIGSERIAL PRIMARY KEY,
    location_id BIGINT NOT NULL REFERENCES locations(id),
    character_id BIGINT NOT NULL REFERENCES chat_users(id),
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',   -- OWNER / MODERATOR / MEMBER
    is_registered BOOLEAN NOT NULL DEFAULT FALSE,
    system_role VARCHAR(50),                      -- должность системы; null = обычный member
    appointed_at TIMESTAMP,                       -- когда назначен на должность
    joined_at TIMESTAMP,
    UNIQUE (location_id, character_id)
);
```

### Начальные данные

При запуске приложения автоматически создаётся:
- Дефолтный район **"Центральный"** (код: CENTRAL)
- 8 системных локаций с `isSystem = true` для этого района
- Базовые комнаты для каждой системной локации

Особенности:
- Площадь Ленина содержит 2 комнаты: "Площадь" и "Тёплые трубы" (для бомжей)
- Все остальные системные локации содержат по 1 базовой комнате
- Записи `location_users` в системных локациях создаются **только при назначении** на должность —
  авто-членства для всех жителей района больше нет (упразднено вместе с `autoJoinSystemLocations`).

## Backend API

### Endpoints

#### GET /api/districts
Получить список всех районов.

**Response:**
```json
[
  {
    "id": 1,
    "code": "CENTRAL",
    "name": "Центральный район",
    "description": "Первый район города...",
    "systemLocations": [...]
  }
]
```

#### GET /api/districts/{id}
Получить район по ID со списком его системных локаций.

#### GET /api/districts/{id}/system-locations
Получить только системные локации конкретного района.

#### POST /api/location-users/appoint-system-role?locationId&characterId&systemRole
Назначить персонажа на должность в системной локации (ADMIN платформы или глава локации; назначаемый — житель того же района).

#### DELETE /api/location-users/remove-system-role?locationUserId
Снять персонажа с должности.

#### GET /api/location-users/{locationId}/system-roles
Должности системной локации с именами занимающих (для UI мэрии/банка и т.п.).

## Структура кода

```
babich-app/src/main/java/com/platform/chat/
├── entity/
│   ├── District.java              # Entity района
│   ├── Location.java              # Единая entity (isSystem + type + category/xpLocation/gangId)
│   ├── LocationUser.java          # Членство в любой локации + systemRole/appointedAt
│   ├── Gang.java                  # Минимальная заготовка группировки (без FK)
│   ├── Room.java                  # Комната (location_id, без public_location_id)
│   └── ChatUser.java              # Персонаж (district_id)
├── enums/
│   ├── PublicLocationType.java    # Типы системных локаций (8 типов)
│   ├── LocationCategoryType.java  # BUSINESS / HOME (все локации)
│   ├── SystemRoleType.java        # GOVERNOR, POLICE_OFFICER и т.д. (бывший LocationPostType)
│   └── LocationUserRole.java      # OWNER / MODERATOR / MEMBER
├── repository/
│   ├── district/
│   │   └── DistrictRepository.java
│   └── location/
│       ├── LocationRepository.java
│       └── LocationUserRepository.java
├── service/
│   ├── district/
│   │   └── DistrictService.java
│   └── location/
│       ├── LocationService.java
│       └── LocationUsersService.java
├── controller/
│   ├── district/
│   │   └── DistrictController.java
│   └── location/
│       ├── LocationController.java
│       └── LocationUsersController.java
└── dto/response/
    ├── DistrictResponse.java
    ├── LocationResponse.java
    └── ...
```

## Примечания

- Районы создаются только администраторами платформы
- Системные локации нельзя удалить или изменить пользователям
- Каждый район имеет фиксированный набор из 8 типов локаций
- Приватные локации (жильё) также относятся к району через поле `district_id`
- Записи `location_users` в системных локациях появляются только при назначении на должность (`appointSystemRole`) — авто-членства и ручного вступления нет
- Должность хранится в поле `location_users.system_role` (упразднена таблица `location_posts`)

## Назначение на должность (LocationUsersService.appointSystemRole) — «как реализовано»

- **Доступ**: `POST /api/location-users/appoint-system-role?locationId&characterId&systemRole` — ADMIN платформы
  (`ChatRole.ADMIN`) или глава локации (GOVERNOR для мэрии, BANK_DIRECTOR для банка и т.д. — карта `HEAD_ROLES`).
- **Назначаемый** должен быть жителем того же района (замена прежней проверки membership).
- **Локация** должна быть системной; роль — допустимой для её типа (карта `ALLOWED_ROLES`).
- **Авто-права**: при назначении головы локации member автоматически получает `role = MODERATOR`.
- **Идемпотентность**: если персонаж уже занимает эту же должность — тихий успех; если должность занята другим — `400` «Должность уже занята».
- **Уникальность** обеспечивает `unique(location_id, character_id)` — один персонаж = одна запись = максимум одна должность в локации.
- **Глобальный обработчик ошибок** `controller/GlobalExceptionHandler` (`@RestControllerAdvice`): необработанные `RuntimeException` с текстом → `400 {..., message}`, без текста (NPE и т.п.) → `500`; `DataIntegrityViolationException` → `409`; некорректный enum/число в `@RequestParam` → `400`. Локальные `@ExceptionHandler` (Work/Election) имеют приоритет.
- **Известное ограничение** (перенесено с `LocationPost`): в `SystemRoleType` DEPUTY/POLICE_OFFICER/BANK_EMPLOYEE помечены «N слотов», но `unique(location_id, character_id)` и логика `== null` допускают пока один слот на персонажа. Если нужны N-слотовые должности — расширить проверку в `LocationUsersService`.