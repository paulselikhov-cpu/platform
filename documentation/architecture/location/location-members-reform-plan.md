# План миграции: реформа модели локаций (LocationUser / упразднение LocationPost)

> ✅ **Реализовано.** Этот файл был документом-планом; после реализации факты
> «как реализовано» разнесены: детали модели/БД/endpoint'ов — в
> `architecture/world/districts-and-public-locations.md`, разрешения — в
> `service/location/LocationUsersService.java` (комментарии), выборы — §3.5 ниже.
> Здесь, в плане, ниже точная картина целевой модели и сделанные изменения.

## 1. Зачем

Сейчас `LocationUser` используется для двух несовместимых вещей:

1. **Членство в пользовательских локациях** (владелец, модератор, участники,
   invite-код, unread-рассылка) — легитимная работа сущности.
2. **Суррогатное членство в системных локациях**: `ChatUserService.autoJoinSystemLocations()`
   при создании персонажа добавляет его MEMBER'ом во **все** системные локации района.
   Причины, по которым это сделано:
   - `LocationPostService` требует membership при назначении должности;
   - `UnreadService` рассылает unread по members.

Последствия: `location_users` раздувается (жители × 8–15 системных локаций),
unread-рассылка в системных локациях уходит всему району, «member» теряет смысл.

**Решение**: должности (сейчас `LocationPost`) переезжают в `LocationUser`
(две роли на member), `LocationPost` упраздняется, auto-join удаляется.
Member системной локации = держатель должности = получатель уведомлений.
Писать в системную локацию можно без членства.

## 2. Целевая модель

### 2.1. LocationUser (изменения)

```java
public class LocationUser {
    // существующее
    private Location location;
    private ChatUser character;
    private LocationUserRole role;        // OWNER / MODERATOR / MEMBER
    private Boolean isRegistered;           // как сейчас

    // новое
    private SystemRoleType systemRole;      // должность; null = обычный member
    private LocalDateTime appointedAt;      // переезд из LocationPost
}
```

Ограничения:
- `UNIQUE (location_id, character_id)` — как сейчас; один персонаж = одна запись
  = максимум одна должность в локации (текущее поведение LocationPost такое же).
- Для системных локаций `role` заполняется автоматически:
  глава локации (GOVERNOR, BANK_DIRECTOR, ...) → `role = MODERATOR`.
- Для пользовательских локаций `systemRole` = null,
  кроме BUSINESS/HOME — там допустимы должности (см. 2.3).

### 2.2. Упразднение LocationPost

Удаляются: `entity/LocationPost`, `repository/location/LocationPostRepository`,
`service/location/LocationPostService`, `controller/location/LocationPostController`,
DTO постов, `LocationPostType`.

Перенос: назначение/снятие должности → методы `LocationUsersService`
(`appointSystemRole`, `removeSystemRole`) с проверками:
- локация системная (для системных должностей) или category = BUSINESS/HOME;
- назначающий имеет право (мэрия — GOVERNOR; банк — BANK_DIRECTOR; и т.д. —
  права переносим из текущего `LocationPostService`);
- назначаемый — житель того же района (замена проверки membership);
- должность допустима для типа локации (карта из 2.3);
- идемпотентность: та же должность — тихий успех, другая — 400.

Потребители `LocationPost` (найдены grep'ом):
- `modules/poll/handler/ElectionResultHandlerAdapter` — назначение GOVERNOR;
- `modules/poll/service/PollService` — выборы мэра;
- `LocationPostService` / `LocationPostController` — CRUD должностей;
- DTO панели пользователей (опционально: поле должности в `LocationUserResponse`).

### 2.3. Enum'ы

```java
public enum SystemRoleType { // (Прежде был LocationPostType) 
    // === Мэрия (CITY_HALL) ===
    GOVERNOR,           // Глава администрации района — 1 слот
    MAYOR,              // Мэр — 1 слот
    DEPUTY,             // Депутат — N слотов

    // === Полицейский участок (POLICE_STATION) ===
    POLICE_OFFICER,     // Полицейский — N слотов (фиксированное число на район)

    // === Банк (BANK) ===
    BANK_DIRECTOR,      // Директор банка — 1 слот
    BANK_EMPLOYEE,      // Сотрудник банка — N слотов

    // === Рынок недвижимости (REAL_ESTATE_MARKET) ===
    REAL_ESTATE_DIRECTOR // Владелец рынка недвижимости — 1 слот
} 

public enum LocationCategoryType {
    BUSINESS, HOME;
    // системным локациям категория проставляется при инициализации района
}
```
При назначении головы member автоматически получает `role = MODERATOR`.
Т.е. при выборах губернатора, остальных главных по локациям губернатор будет устанавливать сам через меню в кабинете губернатора (пока есть только кнопки)


### 2.4. Location (изменения)

```java
private LocationCategoryType category;  // nullable; проставляется всем при создании
private Long xpLocation = 0L;           // XP самой локации; только пользовательским
private Long gangId;                    // без FK — entity Gang появится позже
```

- `xpLocation` — XP самой локации как игрового объекта (прокачка заведения);
  системным не начисляется.
- `gangId` — nullable `Long`, без `@ManyToOne`, целостность на стороне сервиса.
  При появлении полноценного Gang — перевести на связь.
- Минимальная заготовка `entity/Gang.java` (id, name, district) — в этом же изменении.

### 2.5. Переименование LocationMember → LocationUser

Сущность переименовывается целиком в этом же изменении: «member» перестаёт быть
термином (в системных локациях members = штат с должностями), членство =
«пользователь локации». Код наполовину уже на «users»: DTO называется
`LocationUserResponse`, фронт-интерфейс — `ILocationUser`.

| Было | Станет |
|---|---|
| `entity/LocationMember` | `entity/LocationUser` |
| таблица `location_members` | `location_users` |
| `LocationMemberRepository` | `LocationUserRepository` |
| `LocationMembersService` | `LocationUsersService` |
| `LocationMembersController` | `LocationUsersController` |
| `LocationMembersPagedResponse` | `LocationUsersPagedResponse` |
| enum `LocationMemberRole` | `LocationUserRole` |
| URL `/api/location-members` | `/api/location-users` (внутри уже `/{locationId}/users`) |
| фронт: `location-members.service.ts`, `models/location-members/` | `location-users.*` |

- Объём: 6 файлов бэка с именем `*LocationMember*`, 16 java-файлов со ссылками,
  5+ ts-файлов фронта (services, models, фичи).
- `ddl-auto: create` — таблица пересоздаётся, миграция данных не нужна.
- URL меняется → фронт правится синхронно в том же изменении.
- Нейминг enum `LocationUserRole` не конфликтует с entity `LocationUser`
  (правило .clinerules: enum с суффиксом роли/типа).

## 3. Изменения по сервисам

### 3.1. ChatUserService
- `autoJoinSystemLocations()` — **удалить** целиком (и вызовы).

### 3.2. LocationUsersService / LocationService
- `joinByInviteCode`, создание OWNER, appointModerator, кик — без изменений
  (пользовательские локации).
- Новые методы: `appointSystemRole(locationId, characterId, systemRole, ...)`,
  `removeSystemRole(...)`.
- «Мои локации» (`LocationService:63`): системная локация попадает в меню,
  только если персонаж — её member (т.е. держит должность).

### 3.3. MessageService (права)
- Нынешнее правило удаления: `role == OWNER || role == MODERATOR`.
- В системной локации модерировать может member, чей `role = MODERATOR`
  (глава получает её автоматически при назначении) — существующая проверка
  продолжает работать без отдельного кода.
- **Право писать** в системную локацию: проверить текущую проверку прав
  отправки — если она требует membership, ослабить до «житель района»
  для системных локаций (требование: «зашёл, пофлудил, ушёл» без членства).

### 3.4. UnreadService
- Правило единое для всех типов локаций: получатели = members локации.
- Для системных локаций members теперь = штат → рассылка перестаёт быть
  массовой. Unread-счётчик по `RoomReadStatus` не завязан на members —
  не менять.
- Не-member, зашедший в комнату системной локации, видит сообщения вживую,
  но уведомлений о новых — не получает.

### 3.5. modules/poll (выборы)
- `ElectionResultHandlerAdapter.handle()`:
  1. найти member с systemRole = GOVERNOR в мэрии → удалить его membership
     (в системной локации membership == должность);
  2. создать member нового мэра (systemRole = GOVERNOR, appointedAt = now,
     role = MODERATOR).
- `PollService` — проверить зависимости от LocationPostService и заменить.

### 3.6. Панель пользователей (users-panel)
- users-panel (`LocationUsersMenu`)
  уже рендерит members (`LocationUsersService.getLocationUsers`), а после
  реформы members системной локации = штат → панель сама показывает,
  кто на посту; фильтр online/offline — кто из штата на связи.
- Единственная правка (опционально): добавить должность в `LocationUserResponse`
  (бэк) и `ILocationUser` (фронт) — чтобы панель показывала «Иван — мэр»,
  а не просто имя.
- Онлайн (физическое присутствие) — без изменений, по `CharacterPresence`.

## 4. Риски и развилки

| # | Риск | Решение |
|---|---|---|
| 1 | Два поля «тип» на Location (`type` — системный, `category` — BUSINESS/HOME) — путаница | Термины зафиксированы: `type` = PublicLocationType (системные), `category` = BUSINESS/HOME. В API/доках не смешивать |
| 2 | `gangId` без FK — висячие ссылки | Валидация на уровне сервиса; FK при появлении Gang |
| 3 | Контракт фронта меняется (post → systemRole) | Согласовать API до реализации; фронт правится отдельно |
| 4 | Удаление LocationPost ломает выборы | `ElectionResultHandlerAdapter` правится в том же изменении; после — прогнать сценарий выборов |
| 5 | BUSINESS_OWNER в пользовательской локации vs OWNER | BUSINESS_OWNER — должность (systemRole), OWNER — управленческая роль; могут сосуществовать на одном member |
| 6 | `xpLocation` — кто и когда начисляет | В этом изменении только поле; механика начисления — отдельный сценарий |
| 7 | `ddl-auto: create` — схема пересоздаётся | Данных переносить не надо; проверить, что в `db/` нет мёртвых миграций (правило .clinerules) |

## 5. Порядок работ

1. Enums: `SystemRoleType`, `LocationCategoryType`, карта допустимых должностей и headRole.
2. Entities: `LocationUser` (+systemRole, appointedAt), `Location` (+category, xpLocation, gangId), минимальный `Gang`; переименование LocationMember → LocationUser по карте 2.5 (бэк + URL + фронт).
3. `LocationUsersService`: appointSystemRole / removeSystemRole + проверки.
4. Удаление `LocationPost*` (entity, repo, service, controller, DTO) — перенести логику назначений.
5. `ChatUserService`: удалить autoJoinSystemLocations.
6. `MessageService`: проверить право отправки в системную локацию (ослабить до «житель района»).
7. `ElectionResultHandlerAdapter` / `PollService`: перевод на member-модель.
8. (Опционально) поле должности в `LocationUserResponse` / `ILocationUser`.
9. `mvn -q compile` → запуск (порт 8080: остановить IntelliJ-инстанс руками) → проверить вход/меню/выборы.
10. Документация: конвертировать этот план в фактическую заметку `architecture/location/`,
    актуализировать `mvp-ai-brief.md`, `stomp-and-chat-service.md` (unread),
    `locations-users-menu-sync.md`, `project-card.md`, `project-status.md`.

## 6. Критерии готовности

- [x] `LocationPost` и его инфраструктура удалены, компиляция зелёная.
- [x] Создание персонажа не создаёт members в системных локациях.
- [x] Переименование выполнено (entity `LocationUser`, таблица `location_users`, URL `/api/location-users`), фронт обновлён.
- [x] Назначение GOVERNOR через выборы работает (member: GOVERNOR + MODERATOR в мэрии).
- [x] Уведомления о сообщениях в системной локации получают только штат.
- [x] Не-member пишет в системную локацию без ошибки.
- [x] users-panel в системной локации показывает штат (members) с фильтром онлайн.
