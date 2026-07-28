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
  - `members` — список участников (LocationMember)

#### 3. LocationPost (Должность в системной локации)
- **Назначение**: Связывает персонажа с должностью в системной локации
- **Поля**:
  - `id` — уникальный идентификатор
  - `location` — системная локация (Location с `isSystem = true`)
  - `character` — персонаж, занимающий должность
  - `post` — тип должности (enum `LocationPost`)
  - `appointedAt` — когда назначен
- **Ограничения**:
  - `UNIQUE (location_id, character_id)` — персонаж не может иметь две должности в одной локации
  - `UNIQUE (location_id, post)` — для единоличных должностей (например, GOVERNOR, BANK_DIRECTOR)

#### 4. LocationMember (Членство в локации)
- **Назначение**: Универсальная таблица-мост `ChatUser` ↔ `Location` для обеих категорий локаций
- Для **приватных** локаций: создаётся при вступлении по инвайту/покупке
- Для **системных** локаций: создаётся **автоматически** при первом входе персонажа в район (см. раздел "Авто-членство")
- Роли: `OWNER`, `MODERATOR`, `MEMBER`

### Типы системных локаций (PublicLocationType)

Согласно концепции (раздел 8), каждый район имеет 8 типов системных локаций:

1. **CITY_HALL** — Мэрия (управление районом)
2. **LENIN_SQUARE** — Площадь Ленина (народные голосования, комната "Тёплые трубы" для бомжей)
3. **POLICE_STATION** — Полицейский участок (база civicRole)
4. **PRISON** — Тюрьма (место содержания нарушителей)
5. **BANK** — Банк (вклады, ипотека)
6. **WAREHOUSE** — Склад (закупка товаров для бизнеса)
7. **GENERAL_MARKET** — Рынок (аналог "Авито", свободная аренда прилавков)
8. **REAL_ESTATE_MARKET** — Рынок недвижимости (купля-продажа локаций)

### Должности системных локаций (LocationPost)

| Должность | Локация | Тип | Слотов | Описание |
|-----------|---------|-----|--------|----------|
| GOVERNOR | CITY_HALL | appointedRole | 1 | Глава администрации района |
| MAYOR | CITY_HALL | appointedRole | N | Мэр (назначается/избирается) |
| DEPUTY | CITY_HALL | appointedRole | N | Депутат |
| POLICE_OFFICER | POLICE_STATION | civicRole | N | Полицейский (фиксированное число слотов на район) |
| BANK_DIRECTOR | BANK | appointedRole | 1 | Директор банка |
| BANK_EMPLOYEE | BANK | appointedRole | N | Сотрудник банка |
| REAL_ESTATE_DIRECTOR | REAL_ESTATE_MARKET | appointedRole | 1 | Владелец рынка недвижимости |

### Авто-членство в системных локациях

При первом входе персонажа в район (назначении района персонажу) автоматически создаются записи `LocationMember` для всех системных локаций этого района:

```
Логика:
1. Персонажу назначен район (district_id в ChatUser)
2. Сервис проверяет: есть ли у персонажа location_members для системных локаций этого района?
3. Если нет — создаёт N записей LocationMember (character, location, role = MEMBER, isRegistered = false)
   для всех Location WHERE isSystem = true AND district_id = ?
4. Если записи уже есть (повторный вход) — пропускаем
```

Это обеспечивает:
- Unread-счётчики работают для системных локаций без изменений
- Presence показывает участников системных локаций
- Системные локации отображаются в списке "мои локации" у персонажа
- Единая модель прав (`LocationMember.role`) для обеих категорий локаций

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
    invite_code VARCHAR(20) UNIQUE,
    is_public BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP
);
```

#### location_posts (должности)
```sql
CREATE TABLE location_posts (
    id BIGSERIAL PRIMARY KEY,
    location_id BIGINT NOT NULL REFERENCES locations(id),
    character_id BIGINT NOT NULL REFERENCES chat_users(id),
    post VARCHAR(50) NOT NULL,
    appointed_at TIMESTAMP NOT NULL,
    UNIQUE (location_id, character_id),
    UNIQUE (location_id, post)  -- для единоличных должностей
);
```

#### location_members (членство в локациях, обе категории)
```sql
CREATE TABLE location_members (
    id BIGSERIAL PRIMARY KEY,
    location_id BIGINT NOT NULL REFERENCES locations(id),
    character_id BIGINT NOT NULL REFERENCES chat_users(id),
    role VARCHAR(20) NOT NULL DEFAULT 'MEMBER',
    is_registered BOOLEAN NOT NULL DEFAULT FALSE,
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
- Записи `location_members` для системных локаций создаются **не при инициализации района**, а при первом входе каждого конкретного персонажа в этот район

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

#### POST /api/location-posts/appoint
Назначить персонажа на должность в системной локации.

**Request:**
```json
{
  "locationId": 1,
  "characterId": 42,
  "post": "POLICE_OFFICER"
}
```

#### DELETE /api/location-posts/{id}/dismiss
Снять персонажа с должности.

## Структура кода

```
babich-app/src/main/java/com/platform/chat/
├── entity/
│   ├── District.java              # Entity района
│   ├── Location.java              # Единая entity (isSystem + type)
│   ├── LocationMember.java        # Членство в любой локации
│   ├── LocationPost.java          # Должность в системной локации
│   ├── Room.java                  # Комната (location_id, без public_location_id)
│   └── ChatUser.java              # Персонаж (district_id)
├── enums/
│   ├── PublicLocationType.java    # Типы системных локаций (8 типов)
│   ├── LocationMemberRole.java    # OWNER / MODERATOR / MEMBER
│   └── LocationPost.java          # GOVERNOR, POLICE_OFFICER и т.д.
├── repository/
│   ├── district/
│   │   └── DistrictRepository.java
│   └── location/
│       ├── LocationRepository.java
│       ├── LocationMemberRepository.java
│       └── LocationPostRepository.java
├── service/
│   ├── district/
│   │   └── DistrictService.java
│   └── location/
│       ├── LocationService.java
│       ├── LocationMembersService.java
│       └── LocationPostService.java
├── controller/
│   ├── district/
│   │   └── DistrictController.java
│   └── location/
│       ├── LocationController.java
│       ├── LocationMembersController.java
│       └── LocationPostController.java
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
- Записи `location_members` для системных локаций создаются автоматически при первом входе персонажа в район — не требуется ручного вступления
- Должности (`location_posts`) создаются отдельно, через механизм назначения (заявка/администратор)