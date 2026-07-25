# Система районов и общественных локаций

## Обзор
Реализация системы районов (Districts) и общественных локаций (Public Locations) согласно концепции babichchat (разделы 0.1 и 8).

## Архитектура

### Основные сущности

#### 1. District (Район)
- **Назначение**: Административная единица, вмещающая жителей и содержащая системные локации
- **Поля**:
  - `id` — уникальный идентификатор
  - `code` — уникальный код района (например, 'CENTRAL')
  - `name` — название района
  - `description` — описание района
  - `publicLocations` — список системных локаций района

#### 2. PublicLocation (Общественная локация)
- **Назначение**: Системная локация района с фиксированным функционалом
- **Поля**:
  - `id` — уникальный идентификатор
  - `district` — район, которому принадлежит локация
  - `type` — тип локации (enum PublicLocationType)
  - `name` — название локации
  - `description` — описание локации
  - `rooms` — комнаты внутри локации

#### 3. PublicLocationType (Типы системных локаций)
Согласно концепции (раздел 8), каждый район имеет 8 типов системных локаций:

1. **CITY_HALL** — Мэрия (управление районом)
2. **LENIN_SQUARE** — Площадь Ленина (народные голосования, комната "Тёплые трубы" для бомжей)
3. **POLICE_STATION** — Полицейский участок (база civicRole)
4. **PRISON** — Тюрьма (место содержания нарушителей)
5. **BANK** — Банк (вклады, ипотека)
6. **WAREHOUSE** — Склад (закупка товаров для бизнеса)
7. **GENERAL_MARKET** — Рынок (аналог "Авито", свободная аренда прилавков)
8. **REAL_ESTATE_MARKET** — Рынок недвижимости (купля-продажа локаций)

### Связи между сущностями

```
District (1) -----> (N) PublicLocation
District (1) -----> (N) Location (приватное жильё может относиться к району)
PublicLocation (1) -----> (N) Room
Location (1) -----> (N) Room
```

**Важно**: 
- Комната (Room) теперь может принадлежать либо приватной Location, либо публичной PublicLocation
- Поля `location_id` и `public_location_id` в таблице `rooms` — взаимоисключающие

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

#### public_locations
```sql
CREATE TABLE public_locations (
    id BIGSERIAL PRIMARY KEY,
    district_id BIGINT NOT NULL REFERENCES districts(id),
    type VARCHAR(50) NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE (district_id, type)  -- один тип локации на район
);
```

#### Изменения в locations
```sql
ALTER TABLE locations 
ADD COLUMN district_id BIGINT REFERENCES districts(id);
```

#### Изменения в rooms
```sql
ALTER TABLE rooms 
ALTER COLUMN location_id DROP NOT NULL;  -- теперь опционально

ALTER TABLE rooms 
ADD COLUMN public_location_id BIGINT REFERENCES public_locations(id);
```

### Начальные данные

При запуске приложения автоматически создаётся:
- Дефолтный район **"Центральный"** (код: CENTRAL)
- 8 системных локаций для этого района (согласно концепции)
- Базовые комнаты для каждой системной локации

Особенности:
- Площадь Ленина содержит 2 комнаты: "Площадь" и "Тёплые трубы" (для бомжей)
- Все остальные системные локации содержат по 1 базовой комнате

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
    "publicLocations": [...]
  }
]
```

#### GET /api/districts/{id}
Получить район по ID со списком его системных локаций.

**Response:**
```json
{
  "id": 1,
  "code": "CENTRAL",
  "name": "Центральный район",
  "description": "...",
  "publicLocations": [
    {
      "id": 1,
      "type": "CITY_HALL",
      "name": "Мэрия",
      "description": "Управление районом..."
    },
    ...
  ]
}
```

#### GET /api/districts/{id}/public-locations
Получить только системные локации конкретного района.

**Response:**
```json
[
  {
    "id": 1,
    "type": "CITY_HALL",
    "name": "Мэрия",
    "description": "..."
  },
  ...
]
```

## Структура кода

```
babich-app/src/main/java/com/platform/chat/
├── entity/
│   ├── District.java              # Entity района
│   ├── PublicLocation.java        # Entity системной локации
│   ├── Location.java              # Обновлён: добавлено поле district
│   └── Room.java                  # Обновлён: добавлено поле publicLocation
├── enums/
│   └── PublicLocationType.java    # Типы системных локаций (8 типов)
├── repository/
│   └── district/
│       ├── DistrictRepository.java
│       └── PublicLocationRepository.java
├── service/
│   └── district/
│       └── DistrictService.java
├── controller/
│   └── district/
│       └── DistrictController.java
└── dto/response/
    ├── DistrictResponse.java
    └── PublicLocationResponse.java
```

## Frontend (TODO)

Для полной интеграции на frontend потребуется:

1. **Модели TypeScript**:
   - `District` interface
   - `PublicLocation` interface
   - `PublicLocationType` enum

2. **Сервисы**:
   - `DistrictService` для работы с API `/api/districts`

3. **UI компоненты**:
   - Отображение системных локаций в sidebar (рядом с приватными локациями пользователя)
   - Возможность перехода в комнаты системных локаций

## Дальнейшее развитие

Согласно концепции, в будущем необходимо реализовать:

1. **Управление районом** (мэр, полиция, судебная система)
2. **Банковская система** (вклады, ипотека)
3. **Рынки** (общий рынок и рынок недвижимости)
4. **Складская система** для бизнеса
5. **Система для бомжей** (ночлег на "Тёплых трубах", восстановление энергии)

## Примечания

- Районы создаются только администраторами платформы
- Системные локации нельзя удалить или изменить пользователям
- Каждый район имеет фиксированный набор из 8 типов локаций
- Приватные локации (жильё) могут относиться к району через поле `district_id`
