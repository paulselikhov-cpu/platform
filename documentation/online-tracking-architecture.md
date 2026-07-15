# Архитектура online-tracking (онлайн-статусы)

## Проблема, которую решаем

В приложении есть два принципиально разных сценария использования "кто онлайн":

1. **Список локаций в сайдбаре** — нужно только число онлайн-пользователей на каждую локацию (может быть десятки локаций одновременно на экране).
2. **Открытая локация** — нужен полный список id пользователей + детальные события (кто зашёл, в какую комнату, кто вышел), чтобы patch-ить список участников и красить индикаторы онлайна на аватарках.

---

## Общая схема

```mermaid
flowchart TB
    subgraph Backend["Бэкенд"]
        PS[PresenceService]
        PS -->|"по каждому событию"| T1["/topic/location.{id}.presence<br/>детальный: characterId, online, roomId"]
        PS -->|"по каждому событию"| T2["/topic/locations.presence-counts<br/>общий: locationId, online"]
        API1["GET /online-ids<br/>полный список id"]
        API2["GET /online-counts?locationIds=..<br/>батч чисел"]
    end

    subgraph Sidebar["Сценарий: сайдбар (список локаций)"]
        LOC_SVC[OnlineTrackingSidebarService]
        LOC_ITEM1[LocationItem #8]
        LOC_ITEM2[LocationItem #9]
        LOC_ITEM3[LocationItem #10]
    end

    subgraph LocationView["Сценарий: открытая локация"]
        PRESENCE_SVC[OnlineTrackingService]
        VIEW[LocationView]
        MENU[LocationUsersMenu]
        CHAT[ChatArea]
    end

    API2 --> LOC_SVC
    T2 --> LOC_SVC
    LOC_SVC --> LOC_ITEM1
    LOC_SVC --> LOC_ITEM2
    LOC_SVC --> LOC_ITEM3

    API1 --> PRESENCE_SVC
    T1 --> PRESENCE_SVC
    PRESENCE_SVC --> VIEW
    VIEW -->|"input: presenceState"| MENU
    VIEW -->|"input: onlineIds"| CHAT
```

---

## Сценарий 1: Сайдбар со списком локаций

**Задача:** показать `👥 N` рядом с каждой локацией в списке, для потенциально большого числа локаций разом.

**Принцип:** один батч-запрос на весь видимый список + один общий WS-топик на всё приложение, а не по одному на локацию.

```mermaid
sequenceDiagram
    participant Sidebar as SidebarComponent
    participant Svc as OnlineTrackingSidebarService
    participant HTTP as GET /online-counts
    participant WS as /topic/locations.presence-counts
    participant Item as LocationItem (×N)

    Sidebar->>Svc: track([8, 9, 10])
    Svc->>HTTP: locationIds=8,9,10
    HTTP-->>Svc: { "8": 0, "9": 0, "10": 1 }
    Svc->>Svc: counts.set(Map)
    Svc->>WS: подписка (один раз на всё приложение)

    Item->>Svc: countFor(8)
    Svc-->>Item: computed signal → 0

    Note over WS: кто-то зашёл в локацию 9
    WS-->>Svc: { locationId: 9, online: true }
    Svc->>Svc: counts.update (9: 0 → 1)
    Svc-->>Item: signal обновился реактивно
```

### Компоненты

| Файл | Роль |
|---|---|
| `OnlineTrackingSidebarService` | Единственный держатель `Map<locationId, count>`, батч-HTTP + один WS-топик |
| `LocationItem` | Просто читает `countFor(locationId)` — не знает про HTTP/WS вообще |

### Ключевые решения

- **`track(locationIds)`** вызывается один раз родительским компонентом списка, когда известен полный набор id локаций.
- **WS-подписка на `/topic/locations.presence-counts` устанавливается один раз** (`ensureGlobalTopicSubscribed`) и живёт всё время работы приложения — не пересоздаётся при каждом вызове `track`.
- **Фильтрация по `trackedIds`** — сервис получает события по *всем* локациям всех пользователей, но обновляет счётчик только для тех id, которые реально отслеживаются (есть в сайдбаре).
- Счётчик локации, где никого нет, всё равно присутствует в ответе (со значением `0`) — важно, чтобы UI не показывал "нет данных" вместо честного нуля.

---

## Сценарий 2: Открытая локация

**Задача:** показать полный список участников, их комнаты, состояние online/offline в реальном времени — для одной конкретно открытой локации.

**Принцип:** один общий поток presence на весь `LocationView`, расшариваемый через `shareReplay({ refCount: true })` между всеми дочерними компонентами (`LocationUsersMenu`, `ChatArea` и их потомками) — вместо того чтобы каждый дочерний компонент сам ходил в сервис.

```mermaid
sequenceDiagram
    participant View as LocationView
    participant Svc as OnlineTrackingService
    participant Snap as GET /online-ids
    participant WS as /topic/location.{id}.presence
    participant Menu as LocationUsersMenu
    participant Chat as ChatArea

    View->>Svc: getPresence$(10)
    Note over Svc: WS-подписка ДО снапшота —<br/>события не теряются во время загрузки
    Svc->>WS: подписка
    Svc->>Snap: запрос начального списка
    Snap-->>Svc: [3]
    Svc-->>View: { onlineIds: {3}, event: null }

    View->>Menu: input presenceState
    View->>Chat: input onlineIds

    Note over WS: персонаж 7 зашёл в комнату 2
    WS-->>Svc: { characterId: 7, online: true, roomId: 2 }
    Svc-->>View: { onlineIds: {3,7}, event: {...} }
    View->>Menu: обновлённый presenceState (patch loadedUsers)
    View->>Chat: обновлённый onlineIds (зелёный кружок на аватарке)
```

### Компоненты

| Файл | Роль |
|---|---|
| `OnlineTrackingService` | Кеш `Map<locationId, Observable<LocationPresenceState>>`, снапшот + буферизация событий до применения снапшота, `shareReplay({ refCount: true })` |
| `LocationView` | **Единственная точка подписки** на `getPresence$` для этой локации; раздаёт данные вниз через `input` |
| `LocationUsersMenu` | Получает `presenceState` через `input`, не обращается к сервису напрямую |
| `ChatArea` (и вложенные аватарки) | Получает `onlineIds` через `input`, красит индикатор онлайна |

### Ключевые решения

- **Кеш по `locationId` + `shareReplay({ refCount: true })`** — сколько бы компонентов ни подписалось на одну и ту же локацию, реальный HTTP-запрос и WS-подписка происходят один раз; при отписке последнего подписчика поток и WS-подписка закрываются автоматически.
- **Подписка на WS-топик устанавливается ДО запроса снапшота** — события, пришедшие в момент между открытием WS и получением HTTP-ответа, не теряются, а буферизуются и применяются сразу после снапшота.
- **Поднятие подписки на уровень `LocationView`** — раньше и `LocationUsersMenu`, и `ChatArea` независимо вызывали `getPresence$`/`getOnlineIds$`, из-за чего на одну локацию приходилось 2+ подписчика внутри одного и того же поддерева компонентов. Теперь один сигнал `presenceState`/`onlineIds` считается в `LocationView` и спускается вниз как `input` — компоненты-потомки становятся "глупыми" и ничего не знают про сервис.

---

## Бэкенд: откуда берутся данные

```mermaid
flowchart LR
    Enter["PresenceService.enterRoom()"] --> Save[(CharacterPresence)]
    Save --> B1["broadcastPresenceOnline"]
    B1 --> T1["/topic/location.{id}.presence<br/>PresenceEvent(characterId, online, roomId)"]
    B1 --> T2["/topic/locations.presence-counts<br/>LocationPresenceCountEvent(locationId, online)"]

    Disconnect["handleDisconnect() /<br/>cleanupStalePresences()"] --> B2["broadcastPresenceOffline"]
    B2 --> T1
    B2 --> T2
```

### Эндпоинты

| Метод | URL | Возвращает | Используется в |
|---|---|---|---|
| `GET` | `/api/location-members/{locationId}/online-ids` | `List<Long>` — полный список id | `OnlineTrackingService` (снапшот) |
| `GET` | `/api/location-members/online-counts?locationIds=8,9,10` | `Map<Long, Long>` — счётчики батчем | `OnlineTrackingSidebarService` |

### WS-топики

| Топик | Payload | Кто слушает |
|---|---|---|
| `/topic/location.{id}.presence` | `PresenceEvent(characterId, online, roomId)` | `OnlineTrackingService`, по одной подписке на открытую локацию |
| `/topic/locations.presence-counts` | `LocationPresenceCountEvent(locationId, online)` | `OnlineTrackingSidebarService`, одна подписка на всё приложение |

Каждое presence-событие на бэке (`broadcastPresenceOnline`/`broadcastPresenceOffline`) рассылается **в оба топика одновременно** — так оба сценария (сайдбар и открытая локация) получают актуальные данные без дублирования HTTP/WS-инфраструктуры на бэке.

---

## Итоговое сравнение сценариев

| | Сайдбар | Открытая локация |
|---|---|---|
| Сервис | `OnlineTrackingSidebarService` | `OnlineTrackingService` |
| Данные | `Map<locationId, count>` | `Set<characterId>` + события |
| HTTP | 1 батч-запрос на весь список | 1 запрос на локацию (закешированный) |
| WS | 1 общий топик на всё приложение | 1 топик на локацию (закешированный) |
| Кто подписывается | Родитель списка (`track()`), читают все `LocationItem` | `LocationView`, читают потомки через `input` |
| Что получает конечный компонент | Число | Полный набор id + детали события |
