# LocationFeature — главное меню локации, разделы и действия

> Как реализовано (фронтенд `platform-ui`). Отделение ядра (`chat-desktop`,
> `chat-area`) от логики конкретных локаций: главное меню локации, экраны
> разделов и меню «⚡ Действия».

## Проблема, которую решает

Логика специальных локаций (Площадь Ленина — выборы, Мэрия — заявки и
админка) была привязана к комнате: фича жила в `RoomView` и активировалась
только при открытии конкретной комнаты. Из-за этого:

- разделы локации (услуги мэрии, кабинет губернатора) приходилось прятать
  внутри комнат-«обёрток», а не показывать как полноценные экраны;
- `chat-area` знал про конкретные локации (`isLeninSquareRoom()` и т.п.);
- добавление локации требовало правок ядра.

Теперь локация — единица навигации, а комната — просто чат внутри неё.

## Роуты (`app.routes.ts`)

| Роут | Что рисует |
|---|---|
| `/chat/location/:locationId` | redirect на `…/main` (`pathMatch: 'full'`, иначе перехватит `…/main`, `…/feature/*`, `…/room/*` и уйдёт в бесконечный цикл редиректов) |
| `/chat/location/:locationId/main` | `LocationMain` — грид кнопок-разделов фичи |
| `/chat/location/:locationId/feature/:featureId` | `LocationFeatureView` — экран раздела |
| `/chat/location/:locationId/room/:roomId` | `RoomView` — шапка + лента сообщений |

Все варианты грузят один и тот же `ChatDesktop` (`data.page = 'location'`) —
панель целиком рисуется по данным роута, поэтому deep-link с F5
восстанавливает и локацию, и раздел, и комнату.

## Где рисуются действия локации и кнопка «Главная»

Меню «⚡ Действия» фичи (`feature.menuItems`) вынесено **в шапку списка
комнат** (сайдбар), а не в шапку панели: действия относятся к локации в целом,
поэтому должны быть доступны на любом её экране, включая список комнат.

- `ChatDesktop.featureMenuItems` — `computed` от `locationFeature()?.menuItems`;
  шапка рисует `app-actions-menu` только если список непустой;
- `LocationMain` / `LocationFeatureView` в `LocationHeader` `menuItems` **не
  передают** — иначе действие дублировалось бы в двух местах.

Кнопка «Главная» (возврат в `location/:id/main`) — **первым элементом списка
комнат**, отделённая от комнат горизонтальной линией (`room-list__divider`).
`RoomList` эмитит `homeSelected`, `ChatDesktop` слушает его и вызывает
`onRoomListHome()`.

Подсветка активного пункта списка:

- `RoomList.activeHome` — вход от `ChatDesktop.activeHome`
  (`panel() === 'location' && !selectedRoom() && !selectedFeatureId()`),
  то есть ровно на `location/:id/main`; активное состояние рисуется так же,
  как у выбранной комнаты (`--color-accent-muted` + акцентный текст).

## Состояние фичи живёт дольше компонента: `LocationFeatureStore`

`…/main`, `…/feature/:id` и `…/room/:id` — три отдельных routeConfig, поэтому
**каждый** переход (в том числе между комнатами) пересоздаёт `ChatDesktop`.
Если бы фича создавалась прямо в компоненте, её состояние обнулялось бы на
каждом шаге — например, `employeeAuthorized` в мэрии слетал бы при уходе в
комнату и обратно.

Поэтому фича живёт в корневом сервисе `LocationFeatureStore`
(`features/location-feature/location-feature.store.ts`):

- `acquire(location, characterId, injector)` — возвращает фичу из кэша, если
  локация и персонаж те же (состояние сохраняется), иначе освобождает прежнюю
  и создаёт новую с `onEnter()`;
- `release()` — вызывает teardown (например, останавливает поллинг выборов).

Освобождает фичу `ChatDesktop.stopLocationFeature()` — при уходе из локации:
смена локации, `/chat`, `create`/`find`/`work`, ошибка доступа. В `ngOnDestroy`
release **не** вызывается намеренно: пересоздание компонента между комнатами —
не повод терять состояние фичи. Смена локации чистится самим `acquire()`
(разный ключ → `release()`).

## Жизненный цикл: `ChatDesktop`

Фича создаётся **на локацию** (не на комнату) и живёт, пока открыта локация:

```ts
// chat-desktop.ts
private buildLocationFeature(location: ILocation): void {
  this.stopLocationFeature();
  const feature = resolveLocationFeature({ location, injector: this.injector });
  this.locationFeature.set(feature);
  const teardown = feature.onEnter?.();
  if (typeof teardown === 'function') this.locationFeatureTeardown = teardown;
}
```

- `resolveLocationFeature()` вызывается после загрузки локации
  (`loadLocation` → `buildLocationFeature`);
- `onEnter()` может вернуть teardown — так `LeninSquareFeature` останавливает
  поллинг выборов (`stopLocationFeature()` вызывается при смене/закрытии
  локации);
- `injector` — DI-контекст `ChatDesktop`: фича резолвит сервисы через
  `runInInjectionContext` (фича не декорирована `@Injectable`);
- `applyFeature(featureId)` сверяет `featureId` из URL со `screens` фичи;
  неизвестный id → редирект на главное меню.

## Интерфейс (`location-feature.interface.ts`)

```ts
interface LocationFeatureScreen {
  readonly id: string;          // сегмент .../feature/:screenId
  readonly label: string;       // подпись на кнопке раздела
  readonly icon?: string;
  readonly component: Type<unknown>; // standalone-компонент, получает input `feature`
  readonly visible?: () => boolean;  // по умолчанию — виден
}

interface LocationFeature {
  readonly screens: LocationFeatureScreen[]; // кнопки главного меню
  readonly menuItems: RoomMenuItem[];        // пункты «⚡ Действия» в шапке списка комнат
  onMenuSelected?(itemId: string): void;
  onEnter?(): void | (() => void);           // lifecycle + teardown
}
```

`BaseLocationFeature` — абстрактная база: хранит `ctx`
(`{ location, injector }`), пустые `screens`/`menuItems` и заглушки
`onMenuSelected`/`onEnter`. Фабрика вызывает `init(ctx)` сразу после
конструктора, до передачи фичи наружу.

## Фабрика (`location-feature.factory.ts`)

`resolveLocationFeature(ctx)` — switch по **`location.code`**, а не по `type`
(`SystemLocationCode` в `models/location/location-type.enum.ts`):

| `Location.code` | Реализация |
|---|---|
| `CITY_HALL` | `CityHallFeature` |
| `LENIN_SQUARE` | `LeninSquareFeature` |
| `type === BUSINESS` | `BusinessFeature` (заглушка: пустые `screens`/`menuItems`) |
| прочие (`DEFAULT` и остальные системные коды) | `DefaultLocationFeature` |

Выбор идёт по коду потому, что `LocationType` теперь различает только
`SYSTEM`/`DEFAULT`/`BUSINESS` и не говорит, какая перед нами системная локация —
это знает `code`.

Новая локация = новая реализация + одна строка в switch. Ядро (меню, шапка,
чат) ничего про конкретные локации не знает.

## Реализации фич

### `CityHallFeature` (`city-hall/city-hall.feature.ts`)

Объединяет то, что раньше жило в двух фичах комнат — «Приёмная» и
«Кабинет губернатора»:

- **screens** (3): `city-services` «Услуги мэрии» (виден, пока сотрудник не
  авторизован), `employee-office` «Личный кабинет сотрудника» (виден только
  авторизованному), `district-admin` «Панель управления районом» (виден
  текущему губернатору);
- **menuItems** (3): вход/выход из режима сотрудника мэрии, админ-назначение
  себя мэром — с `ConfirmModal`, часть помечена `danger`. После успешного
  `loginAsEmployee` фича делает `router.navigate(['/chat/location', id, 'main'])`:
  состав разделов меняется («Услуги мэрии» сменяется «Личным кабинетом»),
  и грид главного меню показывает актуальный набор.
- **state**: `cityHallPosts` (свежие должности), `employeeAuthorized`
  (сессия «режим сотрудника», не путать с фактом должности),
  `governorCharacterId`, computed `isMayor` / `isAdmin` /
  `isCurrentUserGovernor`;
- **onEnter**: загрузка должностей мэрии через
  `locationUsersService.getSystemRolesByLocation`.

Экраны-компоненты лежат в `city-hall/views/*` и получают фичу как input
`feature`, чтобы читать её сигналы (режим сотрудника, должности).

### `LeninSquareFeature` (`lenin-square/lenin-square.feature.ts`)

- **screens** (1): `election` «Выборы» → `ElectionView`;
- **menuItems**: выдвижение кандидатуры, досрочное завершение выборов
  (видно только админу — бэк отдаёт 403 остальным);
- **state**: `electionOverview`, `electionLoading`, computed
  `hasActiveElection`, `isAdmin`;
- **onEnter**: запускает поллинг `electionService.getOverview` каждые 8 с и
  возвращает teardown с `clearInterval`.

## Главное меню и экран раздела

- `features/location/location-main/` — `LocationMain`: грид кнопок
  (`feature().screens`, отфильтрованный по `visible()`), иконка локации по
  `LOCATION_ICONS[location.type]`, переход `→ /feature/:screenId`; пункты
  «⚡ Действия» берутся из той же фичи.
- `features/location/location-feature-view/` — `LocationFeatureView`:
  находит `screen` по `screenId` из URL и рендерит его компонент через
  `ngComponentOutlet`, передавая `{ feature }` в inputs. В шапке — кнопка
  «назад» в главное меню и меню «⚡ Действия» фичи.

Оба компонента используют общий `app-location-header`
(`shared/components/location-header/`), как и `RoomView`.

## RoomView — чистый чат

`features/location/room-view/room-view.ts` содержит только:

- `app-location-header` (имя комнаты, «печатает…», статус WS, меню
  «⚡ Действия» из `resolveRoomActions()`);
- `chat-area` с лентой сообщений;
- меню участников (`location-users-menu`) и список комнат локации.

В `RoomView` больше **нет** фичи комнаты: специфика локации живёт в её
главном меню. `room-actions.factory.ts` возвращает заглушку пунктов
(помечены `disabled`) — действия самой комнаты ещё не вынесены в фичу.
`room-header/` удалён, шапка — общий `location-header`.

## Точка расширения

1. Создать `location-feature/<тип>/<тип>.feature.ts`
   (extends `BaseLocationFeature`) с `screens` / `menuItems` / `onEnter`.
2. Компоненты экранов положить рядом (`views/…`) — им передаётся input
   `feature`.
3. Добавить ветку в `location-feature.factory.ts`.
4. Для новых типов — значение в enum `LocationType` (фронт и бэк) и иконка в
   `LOCATION_ICONS` (`location-main.ts`).
