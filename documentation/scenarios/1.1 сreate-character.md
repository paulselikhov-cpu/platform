# Сценарий №1.1. Создание персонажа

## Цель
Пользователь создаёт персонажа (ChatUser) для аккаунта в выбранном районе, чтобы начать взаимодействие с игровым миром.

---

## Предусловия
- Пользователь авторизован (JWT-токен действителен)
- Пользователь выбрал район (`districtId` сохранён в `localStorage`)
- У пользователя ещё нет персонажа (ChatUser) в **выбранном районе** (в других районах может быть)

---

## Шаг 1. Получение данных для создания персонажа

**Пользователь:** попадает на форму создания персонажа после попытки войти в район без персонажа.

**Система:**
- Получает `userId` из JWT-токена
- Получает `districtId` из `localStorage` (для последующего перехода в чат и для создания персонажа)
- Подготавливает форму создания с полями из `CreateChatUserRequest`

---

## Шаг 2. Форма создания персонажа

**Пользователь:** видит форму с полями:
- **Имя персонажа** (обязательное, 2-50 символов) — `characterName`
  - Это имя в ролевой игре (отличается от логина)
  - Например: username="ivan123", characterName="Иван Петрович"
- **Пол** (опциональное) — `gender`
- **Вес** (опциональное) — `weight` (в кг)
- **Рост** (опциональное) — `height` (в см)
- **Вредные привычки** (опциональное) — `badHabits`
- **URL аватара** (опциональное) — `avatarUrl`
- Кнопка **«🎮 Создать персонажа»**
- Кнопка **«← Назад»** — возврат к выбору района

**Система:**
- Валидирует поля в реальном времени:
  - `characterName`: обязательно, 2-50 символов
  - `gender`: строка (опционально)
  - `weight`: число (опционально)
  - `height`: число (опционально)
  - `badHabits`: текст (опционально)
  - `avatarUrl`: URL (опционально)
- Показывает ошибки валидации под полями
- Кнопка «Создать персонажа» активна только при валидных данных

---

## Шаг 3. Создание персонажа

**Пользователь:** заполняет форму и нажимает «Создать персонажа».

**Система:**
- Валидирует все поля
- Отправляет запрос:
  - `POST /api/chat/users/{userId}/characters` с телом:
    ```json
    {
      "characterName": "Иван Петрович",
      "districtId": 1,
      "gender": "Мужской",
      "weight": 75.5,
      "height": 180.0,
      "badHabits": "Курение",
      "avatarUrl": "https://example.com/avatar.jpg"
    }
    ```
  - `districtId` — обязательное поле, указывает район, в котором создаётся персонаж
- Backend (`ChatUserService.createChatUser()`):
  1. Проверяет что User существует
  2. Проверяет что у User ещё нет ChatUser в данном районе (1 User = 1 ChatUser per district)
  3. Проверяет уникальность `characterName` в рамках района (не глобально)
  4. Создаёт ChatUser с привязкой к району и дефолтными значениями:
     - `role = ChatRole.USER`
     - `rating = 0`
     - `coinBalance = 0`
     - `xpUser = 0`
     - `energy = 100`
     - `gameStatus = "HOMELESS"`
     - `profession = Profession.DVORNIK`
  5. Сохраняет в БД (таблица `chat_users`)
- При успешном создании:
  - Сохраняет данные ChatUser в `localStorage`
  - Сохраняет `districtId` в `localStorage`
  - Перенаправляет в чат (`/chat`)

**Ошибки:**
- `400 Bad Request` — невалидные данные (имя слишком короткое/длинное)
- `409 Conflict` — персонаж с таким именем уже существует в данном районе
- `409 Conflict` — у пользователя уже есть персонаж в данном районе
- `500 Internal Server Error` — ошибка сервера

---

## Шаг 4. Успешное создание и переход в чат

**Пользователь:** после создания персонажа автоматически попадает в чат (`/chat`).

**Система:**
- Загружает чат с выбранным районом
- Отображает сайдбар с системными локациями
- Показывает уведомление «Персонаж создан! Добро пожаловать в район Центральный»

---

## Шаг 5. Отмена создания

**Пользователь:** нажимает «← Назад» на форме создания.

**Система:**
- Возвращает к выбору района (`/district-select`)
- Персонаж не создаётся

---

## Сводка: статус реализации

| Этап | Описание | Статус |
|------|----------|--------|
| 1 | Получение данных для создания | ❌ Не реализовано |
| 2 | Форма создания персонажа | ❌ Не реализовано |
| 3 | API создания персонажа | ⚠️ Есть базовый эндпоинт, требуется доработка привязки к району |
| 4 | Переход в чат после создания | ❌ Не реализовано |
| 5 | Отмена создания | ❌ Не реализовано |

---

## Технические заметки

### Архитектура ChatUser

**ChatUser** — это персонаж пользователя, привязанный к конкретному району. Один пользователь может иметь множество персонажей, но не более одного персонажа на один район.

**Наследование:**
- `ChatUser extends User` (JOINED inheritance)
- Таблица `chat_users` связана с `users` через `user_id` (FK = PK)
- При запросе Hibernate автоматически делает JOIN двух таблиц

**Поля ChatUser:**
- `id` (PK, FK to users.id) — равен userId
- `characterName` (NOT NULL) — имя в игре
- `districtId` (NOT NULL) — район, к которому привязан персонаж
- `role` (ChatRole: ADMIN, MODERATOR, USER, GUEST) — глобальная роль
- `rating` (Integer, default: 0) — рейтинг
- `coinBalance` (Long, default: 0) — баланс валюты
- `gender` (String, optional)
- `weight` (Double, optional)
- `height` (Double, optional)
- `badHabits` (String, optional)
- `avatarUrl` (String, optional)
- `lastSeen` (LocalDateTime) — последний онлайн
- `xpUser` (Long, default: 0) — накопленный опыт
- `energy` (Integer, default: 100) — текущая энергия
- `energyLastUpdated` (LocalDateTime) — время последнего обновления энергии
- `gameStatus` (String, default: "HOMELESS") — игровой статус
- `profession` (Profession, default: DVORNIK) — профессия

**Важно:** ChatUser имеет поле `districtId`. Персонаж привязан к району и не может существовать вне района. Один User может иметь несколько ChatUser (по одному на район).

**Уникальность:**
- `characterName` уникален в рамках района (составной unique: `(characterName, districtId)`)
- Один User может иметь только одного ChatUser в одном районе (составной unique: `(user_id, districtId)`)

---

### API

**Создание персонажа:**
- `POST /api/chat/users/{userId}/characters` — создание ChatUser для существующего User в указанном районе
  - Request: `CreateChatUserRequest`
    ```json
    {
      "characterName": "Иван Петрович",
      "districtId": 1,
      "gender": "Мужской",
      "weight": 75.5,
      "height": 180.0,
      "badHabits": "Курение",
      "avatarUrl": "https://example.com/avatar.jpg"
    }
    ```
  - Response: `ChatUser` (полный объект с дефолтными значениями)
  - Валидация:
    - `characterName`: @NotBlank, @Size(min=2, max=50)
    - `districtId`: @NotNull
    - Уникальность имени проверяется в рамках района
    - Один User может иметь только одного ChatUser в районе

**Получение персонажей:**
- `GET /api/chat/users/{userId}/characters` — все персонажи пользователя
- `GET /api/chat/users/{userId}/characters?districtId={districtId}` — персонаж пользователя в конкретном районе
- `GET /api/chat/characters/top` — топ по рейтингу (глобальный)
- `PATCH /api/chat/users/{userId}/characters/{characterId}/rating` — обновить рейтинг

---

### Frontend

**CharacterCreateComponent** — форма создания персонажа (роут `/character-create`)
- Получает `userId` из AuthService
- Получает `districtId` из `localStorage` (для создания персонажа и перехода в чат)
- Форма с полями из `CreateChatUserRequest` (включая `districtId`)
- Валидация:
  - `characterName`: обязательно, 2-50 символов
  - Остальные поля опциональны
- После успешного создания → `router.navigate(['/chat'])`

**DistrictSelect** — проверка персонажа при выборе района:
- Проверяет наличие ChatUser в выбранном районе: `GET /api/chat/users/{userId}/characters?districtId={districtId}`
- Если ChatUser не найден → `router.navigate(['/character-create'])`
- Если ChatUser найден → показывает профиль и кнопку «Войти в район»

---

### Backend

**ChatUserService** — бизнес-логика:
- `createChatUser(userId, request)`:
  1. Проверяет существование User
  2. Проверяет что у User нет ChatUser в указанном районе
  3. Проверяет уникальность characterName в рамках района
  4. Создаёт ChatUser с привязкой к району и дефолтными значениями
  5. Сохраняет в БД
- `getChatUserByUserIdAndDistrict(userId, districtId)` — получить персонажа пользователя в районе
- `getAllChatUsersByUserId(userId)` — получить всех персонажей пользователя
- `updateLastSeen(userId, districtId)` — обновить время последнего онлайна
- `updateRating(userId, districtId, delta)` — обновить рейтинг

**ChatUserRepository** — методы:
- `findByUserIdAndDistrictId(userId, districtId)` — найти по userId и districtId
- `findByUserId(userId)` — найти всех персонажей пользователя
- `existsByCharacterNameAndDistrictId(characterName, districtId)` — проверить уникальность имени в районе
- `existsByUserIdAndDistrictId(userId, districtId)` — проверить существование персонажа в районе
- `findAllByOrderByRatingDesc()` — топ по рейтингу

**Валидация:**
- Имя персонажа уникально в рамках района (не глобально)
- Один пользователь может иметь только одного ChatUser в районе
- Минимальная длина имени: 2 символа
- Максимальная длина имени: 50 символов
- `districtId` обязателен при создании

---

### Схема навигации (роутинг)
```
/login → /main-menu → /district-select → /character-create (если нет персонажа в районе) → /chat
/register ↗
```

### Интеграция с Сценарием №1
- После успешного создания ChatUser пользователь автоматически попадает в `/chat`
- ChatUser сохраняется в `localStorage` для быстрого доступа
- При повторном входе в район проверка ChatUser происходит автоматически по `userId + districtId`
- ChatUser привязан к району: один персонаж работает в одном районе
- Один User может иметь по одному персонажу в каждом районе

### Отличия от первоначальной документации
- **ChatUser** — это персонаж для конкретного района, а не глобальный персонаж
- Добавлено поле `districtId` в ChatUser (обязательное)
- Связь User ↔ ChatUser: 1:N (раньше было 1:1)
- Ограничение: 1 User = 1 ChatUser per district
- `characterName` уникален в рамках района (не глобально)
- Нет поля `stats` (сила, ловкость, интеллект) — только базовые характеристики
- Нет `level` и `experience` — есть `xpUser` (накопленный опыт)
- Нет `coinBalance` в DTO создания — устанавливается автоматически (0)
- Профессия по умолчанию: `DVORNIK` (дворник)
- Наследование от User через JOINED strategy (user_id = PK + FK)