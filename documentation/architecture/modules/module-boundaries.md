# Границы модулей: двухплоскостная проверка

> Факты о текущей реализации. Тест: `babich-app/src/test/java/com/platform/ModuleBoundaryTest.java`.
> Объявление модулей — `@ApplicationModule` в `package-info.java` каждого пакета
> (`allowedDependencies` — разрешённые направленные зависимости, `type` — OPEN/CLOSED).

## 1. Правило слоёв дерева `com.platform.chat.*`

| Слой | Знает про | Не знает про |
|---|---|---|
| `domain.*` (онтология мира: chatUser, location, room, district) | другие пакеты `domain.*`, узкие интерфейсы `auth` (`auth::userRepository`) | `engines`, `features` |
| `engines.*` (движки: chatRoom, poll, economy, notification, application, webSocket, scheduledCheck, domainEvent, transactionLog) | `domain.*`, узкие интерфейсы `auth` (`auth::JwtService`) | `features` |
| `features.*` (прикладные фичи: work, governorElection, application, gang, domainEvent) | `domain.*`, `engines.*`, узкие интерфейсы `auth` | — |

`com.platform.auth` — отдельный модуль `type = CLOSED` (для него `allowedDependencies`
управляет, куда модуль может обращаться сам; наружу он отдаёт только классы,
помеченные `@NamedInterface`).

Направленная зависимость объявляется в `package-info.java` целевого модуля, например
`engines.poll` → `{"chat.domain.chatUser", "chat.domain.district", "chat.domain.location",
"chat.engines.scheduledCheck", "chat.engines.domainEvent"}`.

## 2. Первая плоскость: байткод (Spring Modulith)

`ModuleBoundaryTest.verifyModuleStructure()` вызывает
`ApplicationModules.of(PlatformApplication.class).detectViolations().throwIfPresent()`:

- незаявленная направленная зависимость между модулями — падение теста;
- любой цикл между модулями — падение теста.

**Исключающих фильтров нет.** Раньше в тесте стоял фильтр известного цикла
`chat ↔ economy` (сначала по префиксу `"Cycle detected: Slice chat"`, затем по точному
тексту), который глушил и новые циклы. Цикл устранён (см. §4), фильтр удалён —
`detectViolations()` вызывается без исключений.

## 3. Вторая плоскость: проверка исходников

`enginesMustNotImportFeatures()` и `domainMustNotImportEnginesOrFeatures()` читают
текст `.java` под `src/main/java/com/platform/chat/{engines,domain}` и валят тест,
если найден `import com.platform.chat.features.` (для `engines`) либо
`import com.platform.chat.engines.` / `import com.platform.chat.features.` (для `domain`).

Зачем вторая плоскость: `public static final String` с литералом javac **инлайнит**
в точке использования. Импорт класса-носителя константы исчезает из байткода —
зависимости не остаётся, и Modulith её не видит. Проверка текста ловит и такие
ссылки, поэтому обязательна наравне с байткодной.

## 4. Устранённый цикл `engines.poll ↔ features.governorElection`

- было: `PollService` (engines) импортировал `features.governorElection.ElectionClose`
  только ради константы `CHECK_TYPE` — направленный цикл, невидимый для Modulith
  именно из-за инлайна константы;
- стало: константа `POLL_CLOSE` живёт в `engines.poll.PollCheckType`
  (`PollCheckType.POLL_CLOSE`), `PollService` использует её при планировании чека
  закрытия голосования;
- `ElectionClose.CHECK_TYPE` — алиас, ссылающийся на `PollCheckType.POLL_CLOSE`
  (обратная совместимость для существующих чеков), импорт `features` из `engines` удалён.

## 5. Что покрывает `ModuleBoundaryTest`

| Тест | Плоскость | Что ловит |
|---|---|---|
| `moduleStructureIsRecognized` | Modulith | модули читаются, `chat.domain.chatUser` существует |
| `verifyModuleStructure` | байткод | незаявленные зависимости и любые циклы, без исключений |
| `enginesMustNotImportFeatures` | исходники | `engines → features` (в т.ч. инлайн-константы) |
| `domainMustNotImportEnginesOrFeatures` | исходники | `domain → engines`, `domain → features` |

Тест не требует БД и Spring-контекста — это статический анализ структуры пакетов
и исходников, выполняется на каждой сборке.

## 6. Связанные заметки

- Границы слайса доменных событий (ядро шины ↔ реакции): `architecture/event/domain-event-module-layers.md`, §5.
- Ядро заявок и его зависимости: `architecture/application/application-module-layers.md`.
