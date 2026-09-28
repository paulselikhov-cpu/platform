# Модуль заявок: ядро процесса и исполнители

> Факты о текущей реализации (после рефакторинга модуля заявок). Намерение —
> `vision/concept.md`, сценарий — `scenarios/3.1 work-licence-application.md`,
> карта кода — `system-model/mvp-ai-brief.md`.

## 1. Два слайса вместо одного «разорванного»

| Слайс | Пакет | Роль |
|---|---|---|
| Ядро процесса | `com.platform.chat.core.modules.application` | Жизненный цикл заявки: `Application`, `ApplicationType`, `ApplicationStatus`, порт `ApplicationHandler`, решение `ApplicationDecision`, реестр `ApplicationHandlerRegistry`, команды `ApplicationService`, чтения `ApplicationQueryService`, DTO `ApplicationSummary`, `ApplicationMessages` (i18n) |
| Исполнители + REST | `com.platform.chat.modules.application` | Стратегии `RegisterPassport` / `RegisterWorkLicence` (эффект на `ChatUser` через `ChatUserService`), подача `ApplicationSubmissionService`, `ApplicationController`, DTO модерации `ApplicationView` + `ApplicationViewAssembler` (имена заявителей — через публичный API `auth::userService`, без доступа в чужой репозиторий) |

Зависимость строго однонаправленная: `chat.modules.application → chat.core.modules.application`.
Ядро не знает ни про `chat.base.chatUser`, ни про `auth`, ни про web.

Причина разделения: до рефакторинга `ApplicationType` жил в модуле-исполнителе, а
entity ядра на него ссылалась — это давало направленный цикл между двумя слайсами.
Тест границ его не ловил: фильтр известного цикла `chat ↔ economy` был задан
префиксом `"Cycle detected: Slice chat"` и глушил любой цикл, начинающийся со
слайса `chat.*`. Сейчас фильтр завязан на точный текст известного цикла, поэтому
новый цикл между `chat.*`-слайсами валит `ModuleBoundaryTest`.

## 2. Кто публикует события

Правило: **факты о процессе заявки публикует ядро, факты об изменениях в чужих
модулях — тот, кто эти изменения произвёл.**

| Событие | Кто публикует | Почему |
|---|---|---|
| `ApplicationResolvedEvent` | `ApplicationService` (ядро) | факт уровня процесса «заявка решена»; подписчик `NotificationEventListener` уведомляет заявителя |
| `CharacterUpdatedEvent` | стратегия — через `ApplicationDecision.events()` | знание «я изменил персонажа» есть только у стратегии (выдача паспорта/лицензии) |

Ядро публикует оба вида, но конкретных типов событий-последствий не импортирует:
они приезжают в решении и уходят циклом `decision.events().forEach(eventPublisher::publish)`
в той же транзакции, что бизнес-изменение (outbox-атомарность сохраняется).

Ранее ядро само решало, что «одобрение заявки = персонаж изменился»
(`publishCharacterUpdatedIfApproved` по статусу): заявка, меняющая на одобрении не
`ChatUser`, давала ложный пуш, а отказ, меняющий персонажа, — не давал события вовсе,
и каждый новый тип заявки требовал правки ядра.

## 3. Контракт стратегии

```java
public interface ApplicationHandler {
    ApplicationType getType();
    ApplicationDecision resolve(Application application);
}
```

- эффект стратегия применяет сама и синхронно (обязательный эффект не может быть
  «может быть, случится» — DoD в `architecture/event/how-to-use-event-architecture.md`);
- заявку стратегия не меняет и не сохраняет: статус, текст результата и время
  обработки применяет ядро (`ApplicationService.requirePending` + `applyDecision`);
- события стратегия не публикует, а возвращает в решении.

Реестр `ApplicationHandlerRegistry` строит карту `ApplicationType → handler` один раз
в `@PostConstruct` (по образцу `PollResultDispatcher`): дубликат типа — падение на
старте приложения (`DuplicateApplicationHandlerException`), отсутствие стратегии для
типа — `ApplicationHandlerMissingException` в рантайме.

## 4. Ошибки и HTTP-коды

Типизированные исключения ядра маппятся в `GlobalExceptionHandler`:

| Исключение | Код | Когда |
|---|---|---|
| `ApplicationNotFoundException` | 400 | approve/reject по несуществующему id |
| `ApplicationAlreadyResolvedException` | 400 | заявка уже в APPROVED/REJECTED |
| `ApplicationSubmissionRejectedException` | 400 | подача отклонена правилом (дубль документа, вторая незакрытая заявка типа) |
| `AccessDeniedException` (Spring Security) | 403 | модерация не сотрудником мэрии — фронт по 403 показывает «нет доступа» |
| `ApplicationHandlerMissingException` | 400 (fallback RuntimeException) | для типа заявки нет стратегии |

Отсутствие персонажа у аккаунта отдаётся 400 с текстом
`Персонаж не найден: <id>` (раньше — текст ключа `application.character.not-found`
из модуля заявок; ключ в `messages.properties` остался неиспользуемым).

## 5. Сохранённые контракты и известные ограничения

- Ручки `/api/applications/*` и имена полей JSON не менялись; наружу отдаются DTO
  (`ApplicationSummary` на 5 ручках, `ApplicationView` на `/all`) вместо JPA-entity,
  набор полей сохранён.
- `GET /api/applications/all` отдаётся любому авторизованному — гейт роли не
  применяется (действующее поведение, гейт не добавлялся).
- Число, генерируемое для документа, не проверяется на уникальность
  (`RandomDocumentNumberGenerator`: `<префикс>-XXXX-XXXX`).
- Формат `Application.payload` — TEXT без типизации, поле не читается кодом.
- Модерация не ограничена районом, пагинации на `/all` нет.
