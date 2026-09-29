# Слайс «чат комнаты»: сообщения, непрочитанное, присутствие, STOMP-адаптеры

> Факты о текущей реализации (после объединения бывших слайсов `message`,
> `onlineSession` и переноса STOMP-адаптеров чата). Карта кода — `system-model/mvp-ai-brief.md`,
> присутствие как подсистема — `architecture/presence/online-tracking.md`, read-status —
> `architecture/chat/read-status.md`.

## 1. Консолидация слайса и разделение с WebSocket-инфраструктурой

| Слайс | Пакет | Роль |
|---|---|---|
| Чат комнаты | `com.platform.chat.engines.chatRoom` | Сообщения (`Message`, `MessageService`), непрочитанное (`UnreadService` + `RoomReadStatus`), присутствие (`OnlineSession` + `OnlineSessionService`), REST `/api/messages`, REST состояния комнат под `/api/location-users`, STOMP-контроллер чата `ChatWebSocketController`, слушатель закрытия сессий `WebSocketDisconnectListener`, DTO |
| Инфраструктура WebSocket | `com.platform.chat.engines.webSocket` | Общеплатформенная STOMP-инфраструктура: `WebSocketConfig` (брокер `/topic`, `/queue`, префикс `/user`), `JwtChannelInterceptor` (аутентификация STOMP CONNECT через `auth::JwtService`) |

До рефакторинга:
- существовало два слайса `core.modules.message` и `core.modules.onlineSession` со взаимными зависимостями;
- модуль `webSocket` зависел от `chatRoom` и `chatUser`, смешивая общую конфигурацию STOMP-брокера платформы с обработчиками чата.

После рефакторинга:
- `chatRoom` инкапсулирует весь домен и web/STOMP-адаптеры комнат чата;
- `webSocket` очищен от доменных зависимостей чата и зависит **только от `auth::JwtService`**, обслуживая брокер для всей платформы (включая уведомления и события персонажа).

## 2. Состав слайса chatRoom

| Класс | Ответственность |
|---|---|
| `entity/Message` | Сообщение комнаты (CHAT/ACTION/SYSTEM, soft delete, реплай self-FK) |
| `entity/OnlineSession` | Присутствие: одна строка на персонажа (`character_presence`), `sessionId`, `location`, `room`, `lastHeartbeatAt` |
| `repository/MessageRepository` | История с пагинацией, счётчики, физическое bulk-удаление по комнатам |
| `repository/OnlineSessionRepository` | Сессии по `characterId`/`sessionId`/локации, bulk-heartbeat, очистка при старте |
| `service/MessageService` | `saveByUser`, `getHistoryAndMarkRead`, `getHistory`, `deleteMessage(s)` |
| `service/UnreadService` | Счётчик непрочитанного (`created_at > lastReadAt` и не свои), `markRead`, WS-пуш бейджей |
| `service/OnlineSessionService` | `enterRoom`, `leaveRoom`, `heartbeat`, `handleDisconnect`, очистка протухших сессий через `TickHandler`, счётчики онлайна, WS-presence |
| `service/RoomContentPurgerImpl` | Реализация порта `base.room.port.RoomContentPurger` (чистка сообщений при удалении комнат) |
| `controller/MessageController` | REST `/api/messages/**` |
| `controller/RoomStateController` | REST состояния комнат (`/api/location-users`: unread, online-счётчики) |
| `controller/ChatWebSocketController` | STOMP-эндпоинты: `/chat.history.send`, `/chat.join`, `/chat.typing`, `/chat.leave`, `/chat.read`, `/presence.heartbeat` |
| `eventListener/WebSocketDisconnectListener` | Слушатель `SessionDisconnectEvent` Spring WebSocket, триггерит `OnlineSessionService.handleDisconnect` |

## 3. Что осознанно осталось вне слайса

- `Room`, `RoomCode`, `TemplateRoom`, `RoomService` — базовая модель комнаты (`chat.domain.room`).
- `RoomReadStatus` + его репозиторий — в `chat.domain.room` (FK `room_read_status.room_id → rooms.id` требует удалять отметки до комнат в транзакции `LocationService.deleteLocation`).
- Чистка сообщений инвертирована через порт: `base.room.port.RoomContentPurger`, реализация — `RoomContentPurgerImpl` в `chatRoom`.
- Общеплатформенная конфигурация брокера `/ws` — в `chat.engines.webSocket`.
