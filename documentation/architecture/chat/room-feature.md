# RoomFeature — фичи комнат (меню «⚡ Действия» + контент-панель)

> Как реализовано (фронтенд `platform-ui`). Отделение стабильного ядра
> `chat-area` от логики специальных комнат.

## Проблема, которую решает

Логика спец-комнат (Площадь Ленина — выборы, Кабинет губернатора — админка,
Приёмная — заявки) была размазана по ядру:

- `@if (isLeninSquareRoom())` в `chat-area.html` (таблица) и
  `chat-area-header.html` (меню действий);
- состояние выборов (`electionOverview`, `refreshElection`) и проверка
  «текущий пользователь — губернатор» (`governorCharacterId`,
  `currentUserIsGovernor`) в `chat-area.ts`;
- при добавлении комнаты нужно было править ядро в трёх местах.

При этом меню в шапке и контент в чате связаны: действие «запустить выборы»
должно показать таблицу, т.е. header и контент живут одним состоянием.

## Решение: одна фича на комнату

Каждая специальная комната = **один объект `RoomFeature`**, который объединяет:

1. **Действия** (`menuItems`) — пункты меню «⚡ Действия» в шапке;
2. **Контент** (`contentKey`) — какую панель рендерить в `chat-area`;
3. **Состояние** — сигналы фичи (например `electionOverview`), которые читают
   и меню, и панель. Действие обновляет state фичи → оба потребителя
   перерисовываются автоматически. Отдельной передачи state между header и
   таблицей больше нет.

Ядро `ChatArea` создаёт фичу через фабрику и не знает про конкретику:

```ts
// chat-area.ts
readonly roomFeature = computed(() => {
  const room = this.room(); const location = this.location();
  if (!room || !location) return null;
  return resolveRoomFeature({ room, location, injector: this.injector });
});
```

и передаёт один и тот же объект в header (`[feature]` — меню) и в
`<app-room-feature-panel [feature]="roomFeature()" />` (контент).

## Файлы

```
shared/components/actions-menu/
  actions-menu.ts|html|scss         # рендер меню + ConfirmModal перед run()
  room-menu-item.interface.ts       # RoomMenuItem

features/chat/chat-area/room-feature/
  room-feature.interface.ts         # RoomFeature, RoomFeatureContext,
                                    # RoomFeatureContent, BaseRoomFeature
  room-feature.factory.ts           # resolveRoomFeature(roomCode, ctx) — switch
  room-feature-panel.ts|html|scss   # @switch по feature().contentKey
  features/
    lenin-square.feature.ts         # выборы губернатора
    governors-office.feature.ts     # админка (видна только губернатору)
    reception.feature.ts            # приёмная
  panels/
    election.panel.ts               # обёртка над shared ElectionTable
    governors-admin.panel.ts        # @if (isCurrentUserGovernor())
    reception.panel.ts              # обёртка над ReceptionMenu
```

## Контракты

```ts
interface RoomFeature {
  readonly contentKey: RoomFeatureContent; // 'election' | 'governors-admin' | 'reception'
  readonly menuItems: RoomMenuItem[];
  onMenuSelected?(itemId: string): void;
  onRoomEnter?(): void | (() => void);     // активация; cleanup при смене комнаты
}

interface RoomMenuItem {
  id: string; icon?: string; label: string;
  danger?: boolean;
  confirm?: ConfirmModalConfig;            // есть → ConfirmModal перед run()
  visible?: () => boolean;                 // реактивное скрытие пункта
  run(): void | Observable<unknown> | Promise<unknown>;
}
```

- `ActionsMenu` подписывается на результат `run()` и держит загрузку
  в `ConfirmModal`; ok/error-тосты фича делает сама через `MessageService`
  (внутри `tap({next, error})`).
- Lifecycle: `ChatArea` в effect вызывает `feature.onRoomEnter()`; возвращённый
  cleanup вызывается при смене комнаты и в `ngOnDestroy` (поллинг выборов
  раз в 8с живёт в `LeninSquareFeature.onRoomEnter`).
- Сервисы фича резолвит в конструкторе через
  `runInInjectionContext(ctx.injector, () => { ... = inject(Service) })` —
  DI-контекст chat-area (в текущей версии Angular `inject(token, {injector})`
  не поддерживается).

## Как добавить новую комнату

1. Создать `room-feature/features/<room>.feature.ts` (extends `BaseRoomFeature`):
   задать `contentKey`, при необходимости `menuItems` и `onRoomEnter`.
2. Создать панель в `room-feature/panels/` и `@case` в `room-feature-panel.html`
   (если нужен контент) — либо переиспользовать существующий contentKey.
3. Добавить строку в `room-feature.factory.ts`.

Ядро `chat-area.ts/.html` и `chat-area-header` при этом не меняются.
