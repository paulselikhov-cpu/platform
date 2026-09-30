# Маршрутизация локации/комнаты и контроль доступа

> «Как реализовано». Факты о текущем коде (frontend `platform-ui`, backend `babich-app`).

## Проблема

Раньше текущая локация/комната хранились в сигналах `ChatDesktop` и переживали
F5 через localStorage (`babich_last_location_id`, `babich_last_rooms`). Это дублировало
состояние вне URL: нельзя было поделиться ссылкой на комнату, а при F5 страница
сама «угадывала» локацию из localStorage.

## Решение: URL как источник истины

Состояние панели целиком кодируется в маршруте под `/chat` (`app.routes.ts`):

| URL | Страница |
|---|---|
| `/chat` | пусто (список локаций в сайдбаре) |
| `/chat/location/create` | создать локацию |
| `/chat/location/find` | найти локацию |
| `/chat/work` | работы |
| `/chat/location/:locationId` | локация без комнаты — список комнат + «добро пожаловать в локацию» |
| `/chat/location/:locationId/room/:roomId` | выбранная комната (переживает F5) |
| `/chat/error` | страница «доступ запрещён» |

- `ChatLayout` — родитель всех `/chat`-маршрутов; desktop-ветка рендерит
  `<router-outlet/>`, куда подставляются `ChatDesktop` / `ChatAccessError`.
- `ChatDesktop` — роутируемый компонент: читает `page` из `route.snapshot.data`,
  а `locationId`/`roomId` из параметров маршрута, объединяя их с сигналом
  текущего персонажа через `combineLatest(route.params, toObservable(currentChatUser))`
  (оба участника — так переход срабатывает и когда параметры меняются, и когда
  подтянулся персонаж).
- Все действия пользователя (выбор локации/комнаты, создать/найти/работать/главная)
  — это `router.navigate([...])`, а не прямое изменение сигналов.
- Подсветка активной локации в сайдбаре идёт из входа `[activeLocationId]`
  (`selectedLocation`), localStorage не используется.

## Контроль доступа к локации

Доступ проверяется по deep-link `/chat/location/:id` (и `/room/:id`) через новый
endpoint `GET /api/locations/{locationId}?characterId=` →
`LocationService.getLocationForView`:

- **системная локация** (`isSystem`) — доступ всем жителям (без членства);
- **публичная** (`isPublic`) — доступ всем;
- **приватная** (не public) — только `LocationUser` (member) текущего персонажа,
  иначе `AccessDeniedException` → HTTP **403**.

Отсутствие локации → `LocationNotFoundException` → HTTP **404** (обработчик в
`GlobalExceptionHandler`).

`ChatDesktop.loadLocation` по статусу ответа уводит со страницы локации:
**404 → `/chat/error?reason=not-found`**, **403 → `/chat/error?reason=forbidden`**,
иначе — на `/chat`. Причина передаётся query-параметром, поэтому страница
переживает F5 и её можно переслать. Текст причины тоже берётся с бэкенда:
`message` из тела 403/404 кладётся в тот же URL (`&message=…`) — продуктовую
формулировку («не участник») фронт не хардкодит. `ChatAccessError` по `reason`
выбирает иконку и заголовок (⛔ «Доступ запрещён» для 403, 🔍 «Локация не найдена»
для 404), а текстом показывает `message`, если он есть, иначе fallback-копирайт
из `CONTENT` (прямой заход по ссылке без параметра). Кнопка «На главную» → `/chat`.

## Нюансы реализации

- `toObservable()` вызывается в field initializer (`character$`), потому что он
  требует инъекшн-контекст (в `ngOnInit` падает c `NG0203`).
- Статические сегменты роутов (`location/create`, `location/find`) объявлены до
  параметризованного `location/:locationId` — иначе Angular схлопнул бы их в параметр.
- Смена комнаты внутри одной локации (`/room/a` → `/room/b`) идёт по одному
  routeConfig → компонент переиспользуется, комнаты не перезагружаются
  (только `applyRoom`). Переход «локация без комнаты» → «локация с комнатой» —
  другой routeConfig → `ChatDesktop` пересоздаётся.