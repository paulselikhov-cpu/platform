# RoomView / RoomFeature — фичи комнат: режимы отображения + меню «Действия»

> Как реализовано (фронтенд `platform-ui`). Отделение стабильного ядра
> `chat-area` от логики специальных комнат и переключение режимов
> отображения комнаты.

## Проблема, которую решает

Логика спец-комнат (Площадь Ленина — выборы, Кабинет губернатора — админка,
Приёмная — заявки) была размазана по ядру:

- `@if (isLeninSquareRoom())` в `chat-area.html` (таблица) и
  `chat-area-header.html` (меню действий);
- состояние выборов (`electionOverview`, `refreshElection`) и проверка
  «текущий пользователь — губернатор» (`governorCharacterId`) в `chat-area.ts`;
- при добавлении комнаты нужно было править ядро в трёх местах.

При этом меню в шапке и контент в чате связаны: действие «запустить выборы»
должно показать таблицу, т.е. header и контент живут одним состоянием.

## Решение: одна фича на комнату + режимы отображения

Каждая специальная комната = **один объект `RoomFeature`**, который объединяет:

1. **Действия** (`menuItems`) — пункты меню «Действия» в шапке чата;
2. **Режимы отображения** (`views`) — кнопки внизу `room-view`, каждая ведёт
   на свой компонент, который сменяет ленту сообщений целиком;
3. **Состояние** — сигналы фичи (например `electionOverview`), которые читают
   и меню, и вью режима. Действие обновляет state фичи → оба потребителя
   перерисовываются автоматически.

Фича создаётся и живёт в `RoomView` (владелец переключения режимов), а не в
`ChatArea` — поэтому её состояние (например, сессия «сотрудник мэрии»)
переживает смену активного режима, когда `chat-area` размонтирован:

```ts
// room-view.ts
readonly roomFeature = computed(() => {
  const room = this.selectedRoom(); const location = this.location();
  if (!room || !location) return null;
  return resolveRoomFeature({ room, location, injector: this.injector });
});
```

Тот же объект передаётся в шапку комнаты `app-room-header` (только для меню
«Действия») и в компонент активного режима как `inputs: { feature }`.

## Режимы отображения (views)

- Режим `'chat'` — служебный и есть у всех комнат, кнопки для него в
  `views` не бывает: `BaseRoomFeature.activeViewId` по умолчанию `'chat'`.
- Панель кнопок внизу `room-view` показывается **только если у фичи есть
  хотя бы один видимый view** (`showViewModes`); у обычных комнат кнопок нет
  вообще.
- Кнопка режима видна при `view.visible?.() ?? true` — так приёмная скрывает
  «Личный кабинет» для неавторизованных и «Услуги мэрии» для авторизованных.
- Если активный режим стал невидимым (сотрудник вышел из профиля) — `room-view`
  возвращает активным `'chat'`, чтобы не остаться без подсвеченной кнопки.
- Кнопка «назад» не нужна: активный режим переключается кнопками.

Рендер активного режима в `room-view.html`:

```html
<!-- шапка комнаты: меню присутствия приходит в неё контентом -->
@if (selectedRoom(); as room) {
  <app-room-header [room]="room" [feature]="roomFeature()">
    <app-location-users-menu ... />
  </app-room-header>
}
<!-- контент комнаты: активный режим фичи или чат -->
@if (selectedRoom() && activeView(); as view) {
  <ng-container *ngComponentOutlet="view.component; inputs: { feature: roomFeature() }" />
} @else if (selectedRoom()) {
  <app-chat-area [room]="..." [location]="..." [onlineIds]="..." />
}
```


## Файлы

```
shared/components/actions-menu/
  actions-menu.ts|html|scss         # рендер меню + ConfirmModal перед run()
  room-menu-item.interface.ts       # RoomMenuItem
shared/components/back-button/      # универсальная кнопка «← Назад» (стрелка + label)

features/location/room-view/
  room-view.ts|html|scss            # ядро: шапка комнаты, фича, режимы отображения
  room-header/                      # app-room-header: имя комнаты, «⚡ Действия»
                                    # фичи, статус подключения; меню присутствия
                                    # приходит контентом (ng-content)
  location-users-menu/              # меню присутствия (кто в комнате)
  services/online-tracking.service.ts

features/room-feature/
  room-feature.interface.ts         # RoomFeature, RoomFeatureView,
                                    # RoomFeatureContext, BaseRoomFeature
  room-feature.factory.ts           # resolveRoomFeature(ctx) — switch по RoomCode
  lening-square/
    lenin-square.feature.ts         # выборы губернатора
    election.view.ts|html|scss      # обёртка над shared ElectionTable
  governors-office/
    governors-office.feature.ts     # панель управления районом
    governors-office.view.ts|html|scss
    governors-admin-menu/           # панель управления районом (рендерит view)
  reception/
    reception.feature.ts            # приёмная: авторизация сотрудника мэрии
    reception-menu/                 # подача заявок жителем (общий компонент)
    views/
      employee-office.view.ts|html|scss  # модерация заявок (сотрудник)
      city-services.view.ts|html|scss    # подача заявок (житель)
```

## Контракты

```ts
interface RoomFeature {
  readonly views: RoomFeatureView[];       // доп. режимы (без служебного 'chat')
  readonly activeViewId: Signal<string>;   // 'chat' по умолчанию
  setActiveView(viewId: string): void;
  readonly menuItems: RoomMenuItem[];
  onMenuSelected?(itemId: string): void;
  onRoomEnter?(): void | (() => void);     // активация; cleanup при смене комнаты
}

interface RoomFeatureView {
  readonly id: string;                     // служебный 'chat' не используется
  readonly label: string;                  // подпись на кнопке-режиме
  readonly icon?: string;
  readonly component: Type<unknown>;       // standalone-компонент режима
  readonly visible?: () => boolean;        // реактивное скрытие кнопки
}

interface RoomMenuItem {
  id: string; icon?: string; label: string;
  danger?: boolean;
  confirm?: ConfirmModalConfig;            // есть → ConfirmModal перед run()
  visible?: () => boolean;                 // реактивное скрытие пункта
  run(): void | Observable<unknown> | Promise<unknown>;
}
```

- Компонент режима получает фичу через `input feature` и кастует её к своему
  типу (`computed(() => this.feature() as <Feature>)`).
- `ActionsMenu` подписывается на результат `run()` и держит загрузку
  в `ConfirmModal`; ok/error-тосты фича делает сама через `MessageService`
  (внутри `tap({next, error})`).
- Lifecycle: эффект в `RoomView` вызывает `feature.onRoomEnter()`; возвращённый
  cleanup вызывается при смене комнаты и в `ngOnDestroy` (поллинг выборов
  раз в 8с живёт в `LeninSquareFeature.onRoomEnter`). Эффект держится в
  `RoomView`, а не в `ChatArea`, чтобы поллинг не прерывался, пока активен
  не-чат режим.
- Сервисы фича резолвит в конструкторе через
  `runInInjectionContext(ctx.injector, () => { ... = inject(Service) })` —
  DI-контекст `room-view` (в текущей версии Angular `inject(token, {injector})`
  не поддерживается).
- Шапка комнаты (`app-room-header`) рендерится в `room-view` и видна во всех
  режимах: она не часть `chat-area`. Поэтому действие, доступное в шапке
  (например выход из профиля сотрудника мэрии), может дублироваться внутри
  вью режима — см. `employee-office.view` (кнопка «Выйти»).

## Как добавить новую комнату

1. Создать `room-feature/<room>/<room>.feature.ts` (extends `BaseRoomFeature`):
   задать `views` (если есть доп. режимы), при необходимости `menuItems`
   и `onRoomEnter`.
2. Создать компонент режима в той же папке (`.ts` + отдельные `.html`/`.scss`),
   получающий `input feature`.
3. Добавить строку в `room-feature.factory.ts`.

Ядро `room-view`, `room-header` и `chat-area` при этом не меняются.

## Лента сообщений

Логика ленты (WS-подключение комнаты, история, скролл, контекстное меню,
счётчик непрочитанных) вынесена из `chat-area` в
`features/chat/chat-area/components/chat-area-messages/`. `chat-area` остаётся
композицией: лента + панель ввода/выделения; шапку комнаты
(`app-room-header`) и меню присутствия он не рендерит — они живут в
`room-view`.