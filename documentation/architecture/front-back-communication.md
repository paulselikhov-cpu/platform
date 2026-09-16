# Шпаргалка: взаимодействие фронта и бэка

> Справочник по актуальной кодовой базе (факты, "как реализовано").
> Фронт: `platform-ui` (Angular, `projects/babich-chat-ui`). Бэк: `babich-app` (Spring).
> Два канала связи: **REST (HTTP)** и **WebSocket (STOMP)**.
>
> Транспортные детали:
> - Базовый путь REST — `/api/...`; WebSocket — `wss://<host>/ws` (см. `StompConnectionService`).
> - Подключение к WS идёт с `Authorization: Bearer <token>`.
> - Heartbeat WS — фронт шлёт `/app/presence.heartbeat` каждые 10 сек.

---

## 1. Методы, которые фронт вызывает на бэке

Легенда колонок:
1. **Метод фронта** — метод Angular-сервиса, который вызывает UI.
2. **Где вызывается** — файлы на фронте, из которых дёргается метод (пути от `projects/babich-chat-ui/src/app`).
3. **Ручка на бэке** — HTTP-метод + путь, контроллер.
4. **Что делает** — краткая суть.

### 1.1. Аутентификация и сессия

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `authService.login(req)` | `features/auth/login/login.ts` | `POST /api/auth/login`, `AuthController.login` | Авторизация; сохраняет `token`+`user` в localStorage, ставит сигнал `currentUser`. |
| `authService.register(req)` | `features/auth/register/register.ts` | `POST /api/auth/register`, `AuthController.register` | Регистрация; сохраняет сессию (аналогично login). |
| `authService.logout()` | `features/main-menu/main-menu.ts`, `shared/components/modals/settings-modal/settings-modal.ts`, `shared/components/user-menu/user-menu.ts` | — (клиентская очистка, REST-ручки нет) | Чистит localStorage и сессию, редирект на `/login`. |

### 1.2. Пользователи (legacy CRUD)

> `UserService` (`services/backend-services/base/user-service.ts`) объявлен, но в текущем UI ни один его метод не вызывается.

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `userService.getUsers()` | не используется в UI | `GET /api/users`, `UserController.getAllUsers` | Список всех User. |
| `userService.getUser(id)` | не используется в UI | `GET /api/users/{id}`, `UserController.getUserById` | User по id. |
| `userService.createUser(u)` | не используется в UI | `POST /api/users`, `UserController.createUser` | Создать User. |
| `userService.updateUser(id, u)` | не используется в UI | `PUT /api/users/{id}`, `UserController.updateUser` | Обновить User. |
| `userService.deleteUser(id)` | не используется в UI | `DELETE /api/users/{id}`, `UserController.deleteUser` | Удалить User. |

### 1.3. Персонажи (ChatUser)

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `chatUserService.getChatUserByUserIdAndDistrict(userId, districtId)` | `features/district-select/district-select.ts`; `services/current-chat-user.service.ts` | `GET /api/chat/users/{userId}/characters?districtId=`, `ChatUserController.getChatUserByUserIdAndDistrict` | Персонаж юзера в конкретном районе; `null`, если ещё не создан. |
| `chatUserService.getChatUserByUserId(userId)` | `features/sidebar/sidebar/sidebar.ts` | `GET /api/chat/users/by-user/{userId}`, `ChatUserController.getChatUserByUserId` | Первый найденный персонаж юзера (обратная совместимость). |
| `chatUserService.getAllChatUsersByUserId(userId)` | не используется в UI | `GET /api/chat/users/{userId}/characters/all`, `ChatUserController.getAllChatUsersByUserId` | Все персонажи юзера. |
| `chatUserService.getChatUserById(id)` | не используется в UI | `GET /api/chat/users/{id}`, `ChatUserController.getChatUserById` | Персонаж по PK. |
| `chatUserService.createChatUser(userId, req)` | `services/current-chat-user.service.ts` (из `features/character-create/character-create.ts`) | `POST /api/chat/users/{userId}/characters`, `ChatUserController.createChatUser` | Создать персонажа в районе и назначить текущим. |
| `chatUserService.getChatUserLevel(userId)` | `services/current-chat-user.service.ts` (`loadUserLevel`) | `GET /api/chat/users/{id}/level`, `ChatUserController.getChatUserLevelById` | Текущий уровень персонажа. |
| `chatUserService.getXpThreshold(characterId)` | `services/current-chat-user.service.ts` | `GET /api/chat/users/{id}/xp-threshold`, `ChatUserController.getChatUserXpThreshold` | Порог XP следующего уровня (для прогресс-бара). |
| `chatUserService.getDistrictCharacters(districtId)` | `shared/components/district-users-table/district-users-table.ts` | `GET /api/chat/users/district/{districtId}`, `ChatUserController.listDistrictCharacters` | Список персонажей района (админская таблица, роль ADMIN). |
| `chatUserService.updateRole(characterId, role)` | не используется в UI | `PUT /api/chat/users/{characterId}/role`, `ChatUserController.updateRole` | Сменить роль персонажа (ADMIN; свою роль менять нельзя). |
| `chatUserService.updateCharacterSettings(characterId, body)` | `shared/components/district-users-table/district-users-table.ts` | `PUT /api/chat/users/{characterId}/settings`, `ChatUserController.updateCharacterSettings` | Пач-обновление полей персонажа (роль, профессия, статус, монеты, энергия, рейтинг; ADMIN; `null` — не менять). |

### 1.4. Районы и системные локации

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `districtService.getAllDistricts()` | `features/district-select/district-select.ts`; `features/sidebar/sidebar/sidebar.ts` | `GET /api/districts`, `DistrictController.getAllDistricts` | Список всех районов. |
| `districtService.getDistrictById(id)` | не используется в UI | `GET /api/districts/{id}`, `DistrictController.getDistrictById` | Район по id с системными локациями. |
| `districtService.getSystemLocations(districtId)` | `shared/components/modals/district-info-modal/district-info-modal.ts` | `GET /api/districts/{id}/system-locations`, `DistrictController.getSystemLocations` | Системные локации района (мэрия, площадь Ленина и т.д.). |
| `districtService.getSettings(districtId)` | `shared/components/modals/district-settings-modal/district-settings-modal.ts` | `GET /api/districts/{districtId}/settings`, `DistrictSettingsController.getSettings` | Настройки района (админ-панель, ADMIN/MODERATOR). |
| `districtService.updateSettings(districtId, body)` | `shared/components/modals/district-settings-modal/district-settings-modal.ts` | `PUT /api/districts/{districtId}/settings`, `DistrictSettingsController.updateSettings` | Обновить настройки района (ADMIN/MODERATOR). |

### 1.5. Локации

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `locationService.getPublicLocations()` | `features/location/find-location/find-location.ts` | `GET /api/locations`, `LocationController.getPublicLocations` | Список публичных локаций. |
| `locationService.getMyLocations(characterId)` | `features/location/find-location/find-location.ts`; `features/sidebar/sidebar/sidebar.ts` | `GET /api/locations/my/{characterId}`, `LocationController.getMyLocations` | Локации, в которых состоит персонаж (сайдбар «мои локации»). |
| `locationService.getTemplates()` | `features/location/create-location/create-location.ts` | `GET /api/location-templates`, `LocationTemplateController.getAllTemplates` | Шаблоны для создания локации. |
| `locationService.createLocation(req)` | `features/location/create-location/create-location.ts` | `POST /api/locations`, `LocationController.createLocation` | Создать локацию из шаблона. |
| `locationService.joinLocation(inviteCode, characterId)` | `features/location/find-location/find-location.ts` | `POST /api/locations/join/{inviteCode}?characterId=`, `LocationController.joinLocation` | Вступить в локацию по invite-коду. |
| `locationService.getRooms(locationId)` | `layout/desktop/chat-desktop/chat-desktop.ts` (`loadRooms`) | `GET /api/locations/{locationId}/rooms`, `LocationController.getRooms` | Список комнат локации (открытие локации). |
| `locationService.leaveLocation(locationId, characterId)` | `features/sidebar/sidebar/sidebar.ts` | `DELETE /api/locations/{locationId}/leave?characterId=`, `LocationController.leaveLocation` | Покинуть локацию. |
| `locationService.deleteLocation(locationId, characterId)` | `features/sidebar/sidebar/sidebar.ts` | `DELETE /api/locations/{locationId}?characterId=`, `LocationController.deleteLocation` | Удалить локацию (только владелец). |

### 1.6. Участники локации, присутствие (REST), непрочитанное

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `locationMembersService.getLocationUsers(locationId, params)` | `features/location/room-view/location-users-menu/location-users-menu.ts` | `GET /api/location-members/{locationId}/users?page&size&filter&query`, `LocationMembersController.getLocationUsers` | Paged-список участников локации (поиск + фильтр по присутствию). |
| `locationMembersService.getUnreadCounts(locationIds, characterId)` | `features/sidebar/service/unread-tracking-sidebar.service.ts` | `GET /api/location-members/unread-counts?locationIds&characterId`, `LocationMembersController.getUnreadCounts` | Суммарные непрочитанные по локациям (бейджи сайдбара). |
| `locationMembersService.getUnreadSummary(locationId, characterId)` | `features/sidebar/service/unread-tracking-sidebar.service.ts` (`loadRoomBreakdown`) | `GET /api/location-members/{locationId}/unread?characterId`, `LocationMembersController.getUnreadSummary` | Разбивка непрочитанных по комнатам локации. |
| `locationMembersService.getOnlineCount(locationId)` | помечен `@not_used` | `GET /api/location-members/{locationId}/online-count`, `LocationMembersController.getOnlineCount` | Число онлайн в локации (не используется, см. WS). |
| `locationMembersService.getOnlineCharacterIds(locationId)` | помечен `@not_used` | `GET /api/location-members/{locationId}/online-ids`, `LocationMembersController.getOnlineCharacterIds` | Список онлайн-персонажей локации (не используется, см. WS). |

### 1.7. Сообщения (HTTP — история и удаление)

> Отправка новых сообщений — не REST, а через WebSocket (`/app/chat.history.send`), см. раздел 2.

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `messageService.getMessageHistory(roomId, characterId, page, size)` | `features/chat/chat-area/services/chat-room-history.service.ts` | `GET /api/messages/room/{roomId}?page&size&characterId`, `MessageController.getHistory` | История сообщений комнаты с пагинацией (+ помечает прочитанным). |
| `messageService.deleteMessage(messageId)` | `features/chat/chat-area/services/chat-messages.service.ts` (`deleteSingle`) | `DELETE /api/messages/{id}`, `MessageController.deleteMessage` | Удалить одно сообщение (soft delete). |
| `messageService.deleteMessages(messageIds)` | `features/chat/chat-area/services/chat-messages.service.ts` (`deleteSelected`) | `DELETE /api/messages/batch`, `MessageController.deleteMessages` | Удалить несколько сообщений разом. |

### 1.8. Должности в системных локациях (LocationPost)

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `locationPostService.getPostsByLocation(locationId)` | `shared/components/modals/district-info-modal/district-info-modal.ts` | `GET /api/location-posts/by-location/{locationId}`, `LocationPostController.getPostsByLocation` | Должности локации с именем занимающего (модалка «о районе»). |

### 1.9. Экономика и гражданские заявки

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `workService.workAsDvornik()` | `features/economy/work-page/work-page.ts` | `POST /api/work/dvornik`, `WorkController.workAsDvornik` | Тап-фарм работы «дворник» (награда монетами/XP, кулдаун). |
| `applicationService.buyFirstLocation(payload)`, `ApplicationController.buyFirstLocation` | Подать заявку на покупку первой локации (для «бомжей»). |
| `applicationService.getMyApplications()` | не используется в UI | `GET /api/applications/my`, `ApplicationController.getMyApplications` | Список своих заявок. |

### 1.10. Выборы

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `electionService.getOverview(districtId)` | `features/room-feature/lening-square/lenin-square.feature.ts` | `GET /api/elections/district/{districtId}/overview`, `ElectionController.getOverview` | Состояние выборов района (активные или результат последних) — мини-таблица. |
| `electionService.initiate(districtId)` | `features/room-feature/lening-square/lenin-square.feature.ts` | `POST /api/elections/initiate?districtId=`, `ElectionController.initiate` | Шаг 1 — начать выборы; инициатор — первый кандидат (гейт уровня 3). |
| `electionService.join(pollId)` | `features/room-feature/lening-square/lenin-square.feature.ts` | `POST /api/elections/{pollId}/join`, `ElectionController.join` | Шаг 2 — стать кандидатом в идущих выборах. |
| `electionService.vote(pollId, candidateId)` | `features/room-feature/lening-square/lenin-square.feature.ts` | `POST /api/elections/{pollId}/vote?candidateId=`, `ElectionController.vote` | Шаг 3 — проголосовать за кандидата. |
| `electionService.close(pollId)` | `features/room-feature/lening-square/lenin-square.feature.ts` | `POST /api/elections/{pollId}/close`, `ElectionController.close` | Досрочно завершить выборы, подсчёт голосов + результат. |
| `electionService.getStatus(pollId)` | не используется в UI | `GET /api/elections/{pollId}`, `ElectionController.getStatus` | Статус голосования. |
| `electionService.getCandidates(pollId)` | не используется в UI | `GET /api/elections/{pollId}/candidates`, `ElectionController.getCandidates` | Список кандидатов. |

### 1.11. Уведомления

| Метод фронта | Где вызывается | Ручка на бэке | Что делает |
|---|---|---|---|
| `notificationService.list()` | `shared/components/modals/notification-info-modal/notification-info-modal.ts` | `GET /api/notifications`, `NotificationController.list` | Все уведомления текущего персонажа (свежие сверху). |
| `notificationService.unreadCount()` | `services/notification-unread.service.ts` (`refresh`) | `GET /api/notifications/unread-count`, `NotificationController.unreadCount` | Число непрочитанных (бейдж колокольчика). |
| `notificationService.markRead(id)` | `shared/components/modals/notification-info-modal/notification-info-modal.ts` | `POST /api/notifications/{id}/read`, `NotificationController.markRead` | Отметить уведомление прочитанным. |
| `notificationService.accept(id)` | `shared/components/modals/notification-info-modal/notification-info-modal.ts` | `POST /api/notifications/{id}/accept`, `NotificationController.accept` | Подтвердить действие по уведомлению. |
| `notificationService.decline(id)` | `shared/components/modals/notification-info-modal/notification-info-modal.ts` | `POST /api/notifications/{id}/decline`, `NotificationController.decline` | Отклонить действие по уведомлению. |

---

## 2. WebSocket-события

> Два направления: **слушание** (фронт подписан на STOMP-топик) и **публикация** (фронт шлёт команду на `/app/...`).
> Для полноты указаны и те, и другие, сгруппированные по смыслу.

Легенда колонок (слушание):
1. **Топик / событие** — STOMP-дестинейшн, на который подписан фронт.
2. **Где фронт слушает** — файл/сервис на фронте.
3. **Откуда шлёт бэк** — место на бэкенде, где происходит `convertAndSend` / `convertAndSendToUser`.
4. **Кто его вызывает** — сервис/метод на бэке, который инициирует публикацию.

### 2.0. Соединение и инфраструктура

| Топик/событие | Где фронт «слушает» | Где на бэке | Кто вызывает |
|---|---|---|---|
| Установка WS-соединения `wss://<host>/ws` | `services/backend-services/base/stomp-connection.service.ts` (`Client.activate`) | `WebSocketConfig` (endpoint `/ws`) | Сам фронт: `ensureClient()` от `StompConnectionService` (через `ChatWebSocketService.connect` и пр.) |
| Публикация heartbeat `/app/presence.heartbeat` | (шлёт фронт) `stomp-connection.service.ts` (`startHeartbeat`, каждые 10 сек) | `ChatWebSocketController.heartbeat` → `PresenceService.heartbeat` | Фронт (`StompConnectionService`) |
| Ошибка auth (401) при WS | `stomp-connection.service.ts` (`handleAuthError`) | STOMP-брокер возвращает ошибку | Бэк отклоняет сессию (неверный токен) |

### 2.1. Чат: сообщения комнаты

> Основной канал реалтайм-сообщений. Фронт и слушает топик комнаты, и публикует команды на `/app/...`.

| Топик/событие | Где фронт слушает / шлёт | Где на бэке | Кто вызывает |
|---|---|---|---|
| Слушает `/topic/room.{roomId}` | `services/backend-services/webSocket/chat-websocket.service.ts` (`subscribeToRoom`) | `ChatWebSocketController.sendMessage` (convertAndSend), `MessageService.saveByUser` (convertAndSend) | `ChatWebSocketController` (новое сообщение типа `CHAT`); `MessageService` (системные `JOIN`/`DELETE`) |
| Слушает `/topic/typing.{roomId}` | `chat-websocket.service.ts` (`subscribeToTyping`) | `ChatWebSocketController.typing` (convertAndSend) | `ChatWebSocketController.typing` |
| Шлёт `/app/chat.history.send` | `chat-websocket.service.ts` (`sendMessageWithSaveHistory`) ← `features/chat/chat-area/chat-area.ts` | `ChatWebSocketController.sendMessage` | Фронт (отправка сообщения) |
| Шлёт `/app/chat.join` | `chat-websocket.service.ts` (`notifyJoin`, вызывается из `connect`) | `ChatWebSocketController.joinChat` | Фронт (вход в комнату) |
| Шлёт `/app/chat.typing` | `chat-websocket.service.ts` (`sendTyping`) ← `shared/components/message-input/message-input.ts` | `ChatWebSocketController.typing` | Фронт (индикатор печати) |
| Шлёт `/app/chat.leave` | `chat-websocket.service.ts` (`leaveRoom`) ← `chat-area.ts` | `ChatWebSocketController.leaveChat` | Фронт (выход из комнаты) |
| Шлёт `/app/chat.read` | `chat-websocket.service.ts` (`notifyRead`) | `ChatWebSocketController.markRead` → `UnreadService.markRead` | Фронт (пометить прочитанным) |

### 2.2. Присутствие (Presence)

| Топик/событие | Где фронт слушает | Где на бэке | Кто вызывает |
|---|---|---|---|
| Слушает `/topic/location.{locationId}.presence` | `features/location/room-view/services/online-tracking.service.ts` | `PresenceService.broadcastPresenceDetail` | `PresenceService` (`enterRoom`, `leaveRoom`, `onTick` по heartbeat-таймауту) |
| Слушает `/topic/locations.presence-counts` | `features/sidebar/service/online-tracking-sidebar.service.ts` | `PresenceService.broadcastPresenceCount` | `PresenceService` (`enterRoom`, `leaveRoom`, `onTick`) |

### 2.3. Непрочитанные (Unread)

| Топик/событие | Где фронт слушает | Где на бэке | Кто вызывает |
|---|---|---|---|
| Слушает `/user/queue/unread-updates` | `features/sidebar/service/unread-tracking-sidebar.service.ts` | `UnreadService` (convertAndSendToUser `/queue/unread-updates`) | `UnreadService.notifyRoomUnreadChanged` / `notifySelfRoomRead` |

### 2.4. Уведомления

| Топик/событие | Где фронт слушает | Где на бэке | Кто вызывает |
|---|---|---|---|
| Слушает `/user/queue/notifications` | `services/backend-services/http/notification.service.ts` (`live$`), `services/notification-unread.service.ts`, `shared/components/modals/notification-info-modal/notification-info-modal.ts` | `NotificationEventListener` (convertAndSendToUser `/queue/notifications`) | `NotificationEventListener.onElectionStarted`, `.onElectionClosed`, `.onApplicationResolved` |

---

## 3. Заметки по выявленному состоянию кода

- Сервис `UserService` (legacy CRUD `/api/users`) и ряд методов (`getDistrictById`, `getStatus`/`getCandidates`, `getMyApplications`, `updateRole`, `getAllChatUsersByUserId`, `getChatUserById`, `getOnlineCount`/`getOnlineCharacterIds`) объявлены на фронте, но в текущем UI не вызываются — помечены «не используется в UI».
- Игровые события (монеты, XP, покупка локации, выборы) доходят до фронта не напрямую, а через механизм **DomainEvent → NotificationEventListener → WS-пуш** в `/user/queue/notifications`.
- Реализация присутствия в реальном времени идёт в основном через WS (`/topic/location.{id}.presence`, `/topic/locations.presence-counts`); REST-эндпоинты `online-count`/`online-ids` помечены на фронте `@not_used`.