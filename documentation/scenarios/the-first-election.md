# Сценарий №2. Первые выборы губернатора

**Статус:** ✅ Реализован (backend + frontend end-to-end: контекстное меню «⚡ Действия» на Площади Ленина, мини-таблица голосования, модалки уведомлений/мэрии, REST уведомлений, уведомление о начале выборов)

Первые выборы не отличаются от последующих выборов в губернаторы.
В локации "Площадь Ленина", в шапке выбора комнат, при нажатии на значок "действия" будет доступно контекстное меню с выбором действий.
Выборы проходят на системной локации в комнате "Площадь".

Контекстное меню будет расширяться по ходу наращивания функционала.

ui:
По завершению выборов в shared/components/modals/district-info-modal.ts обновляется информация о том кто теперь губернатор
Уведомления о начале и результатах выборов показываются в shared/components/modals/notification-info-modal.ts

**Требования к уровню:** Кнопку может запустить пользователь только с N-го уровня (PersonLevel, HP-прокачка). По умолчанию 1lvl.

**Гейт-условие:** Выборы доступны только если в районе нет губернатора (проверка LocationPost с ролью GOVERNOR).
Проверка делается на бэке.

## Кнопки в контекстном меню

1. **"Выдвинуть свою кандидатуру в губернаторы"** (доступна если губернатор отсутствует)
2. **"Обжаловать губернатора и запустить переизбрание"** (пока не реализовано — запланировано на второй итерации)

## Форма подтверждения

При нажатии на кнопку — popup (мобилка) / модальное окно (десктоп):
> "Вы уверены что хотите выдвинуть свою кандидатуру в губернаторы?" — [Да!] [Нет!]

После "Да" запускается онлайн-ивент **"Выборы губернатора"**.

---

## Ивент "Выборы губернатора"

### Длительность
24 часа (сутки) — по умолчанию, настраивается админом в «Настройках района» (`election.durationHours`). Автоматически закрывается по истечении срока через планировщик (каждые 60 сек проверка).

### Реализация (backend)

#### Слой 1 (Infrastructure / Data)
| Компонент | Файл | Назначение |
|-----------|------|------------|
| `Poll` | `entity/Poll.java` | Сущность голосования |
| `PollCandidate` | `entity/PollCandidate.java` | Кандидат (слот 1–5) |
| `PollVote` | `entity/PollVote.java` | Голос (characterId, candidateId, weight) |
| `Campaign` | `entity/Campaign.java` | Предвыборная кампания (бонусы к шансу) |
| `CampaignContribution` | `entity/CampaignContribution.java` | Пожертвования в кампанию |
| `Notification` | `entity/Notification.java` | Уведомления (рассылка) |
| `ChatUser` | `entity/ChatUser.java` | Участник (для проверки жив/мёртв) |

#### Слой 2 (Use Cases / Facades)
| Компонент | Файл | Назначение |
|-----------|------|------------|
| `ElectionFacade` | `service/ElectionFacade.java` | Оркестратор: инициация → кандидаты → голосование → закрытие |
| `ElectionScheduler` | `scheduler/ElectionScheduler.java` | Планировщик: раз в 60 сек закрывает просроченные |
| `CampaignService` | `service/CampaignService.java` | Управление предвыборной кампанией |

#### Слой 3 (Business Logic / Services)
| Компонент | Файл | Назначение |
|-----------|------|------------|
| `PollService` | `service/PollService.java` | Создание голосования, занятие слотов, голосование, подсчёт |
| `NotificationService` | `service/NotificationService.java` | Рассылка уведомлений персонажам и районам |
| `PersonLevelService` | `service/level/PersonLevelService.java` | Проверка уровня персонажа (гейт 3+) |

#### Слой 4 (Handlers / Effects)
| Компонент | Файл | Назначение |
|-----------|------|------------|
| `ElectionResultHandler` | `handler/ElectionResultHandler.java` | Назначение победителя на должность губернатора |
| `PollResultHandler` | `handler/PollResultHandler.java` | Общий обработчик закрытия голосования |

### Поток вызовов (sequence)

```
ElectionController
  └─ ElectionFacade
       ├─ PersonLevelService.checkLevel(characterId, 1)   — гейт
       ├─ PollService.createGovernorElection()             — создание Poll + 5 слотов
       │    └─ ChatUserRepository.countByDistrictIdAndLastSeenAfter() — кворум от живых
       │
       ├─ (кто-то) PollService.occupySlot()                — занять свободный слот
       │
       ├─ (кто-то) PollService.castVote()                  — проголосовать
       │    └─ PollVoteRepository.findByPollIdAndCharacterId() — проверка дубля
       │
       ├─ (по таймеру/вручную) PollService.closePoll()    — закрыть
       ├─ PollService.countVotes()                         — подсчёт
       ├─ ElectionResultHandler.handle()                   — назначить губернатора
       └─ NotificationService.notifyDistrict()             — уведомить весь район
```



#### Завершение ивента
- **Канал:** районная рассылка в shared/components/modals/notification-info-modal.ts
- **Текст:** "Выборы губернатора завершены, победил {Имя}."
- **Тип:** `ELECTION_RESULT`, entityId = pollId

#### 3. Подтверждение полномочий (TODO — следующий шаг)
- Победитель получает заявку в в shared/components/modals/application-info-modal.ts  "подтвердить согласие / отказаться"
- После подтверждения: всем "Иванов И.И. официально вступил в должность"
- После отказа: "Иванов И.И. отказался от должности"

### Мини-таблица (frontend)
- Реализован shared-компонент `shared/components/election-table` (см. `platform-ui`).
Появляется в chat-area.html над app-message-input, при условии что локация «Площадь Ленина» (type=LENIN_SQUARE) и комната «Площадь».
Это важно! тк люди должны голосовать именно на площади
- 5 строк + шапка
- В шапке: счётчик "Проголосовали X/Y жителей" + таймер окончания + кнопка "добавить кандидатуру"
- Строки: слот [1–5], имя кандидата или "свободный слот", кнопка "проголосовать" / проценты
- После завершения: таблица результатов "На выборах губернатора победил {Имя}. Поздравляем!"

### Кворум и победитель
- **Кворум:** по умолчанию 50% от живых участников района (был онлайн последние 2 суток) — настраивается админом в «Настройках района» (`election.quorumPercent`, `election.aliveWindowDays`)
- **Победитель:** кандидат, набравший **относительное большинство** (>50% проголосовавших)
- Если кворум не набран — губернатор не назначается (Poll остаётся CLOSED без обработки)



## Определения

**Живой участник района:** персонаж, который был онлайн в последние N суток (`ChatUser.lastSeen`); N настраивается админом в «Настройках района» (по умолчанию 2 суток).

**Губернатор:** персонаж, назначенный на должность `GOVERNOR` в `LocationPost` системной локации района.

**Уровень 3+:** гейт через `PersonLevelService.checkLevel(characterId, 3)` — персонаж должен иметь HP не ниже порога 3-го уровня.

---

## Реализованная связка фронт ↔ бэк (обновление)

### Бэкенд (`babich-app`)
- **Гейт «нет губернатора»** проверяется на бэке в `PollService.createGovernorElection`: старт выборов запрещён, если в районе уже есть `LocationPost GOVERNOR` (мэрия) или уже идут выборы (`Poll` ELECTION ACTIVE/PENDING). Отказ — `400` с текстом.
- **Уведомление о НАЧАЛЕ выборов**: `ElectionStartedEvent` (зарегистрирован в `@JsonSubTypes DomainEvent`), публикуется `ElectionFacade.initiateElection`; `NotificationEventListener.onElectionStarted` рассылает жителям района + WS-пуш (`notificationType=ELECTION_STARTED`).
- **REST уведомлений** `NotificationController` (`/api/notifications`): история, `unread-count`, `/{id}/read`, `/{id}/accept`, `/{id}/decline`.
- **`LocationPostController/by-location`** теперь возвращает `LocationPostView` (с именем персонажа) — нужно модалке мэрии.
- **Единый characterId** в `ElectionController` — внутренний `ChatUser.id` (как ожидает `ElectionResultHandlerAdapter`).
- **Статистика для таблицы**: `GET /api/elections/district/{districtId}/overview` → `DistrictElectionView`.
- **Результат выборов** (`ElectionResultHandlerAdapter`) назначает победителя ТОЛЬКО на должность `GOVERNOR` в мэрии района. (Фикс: ранее победитель получал ещё `POLICE_OFFICER`/`BANK_DIRECTOR`/`REAL_ESTATE_DIRECTOR`, т.к. цикл шёл по всем системным локациям — это был баг.)

### Фронтенд (`platform-ui`)
- `chat-area`: кнопка «⚡ Действия» (Площадь Ленина) → выпадающее меню «Выдвинуть свою кандидатуру в губернаторы» → форма подтверждения (ConfirmModal, «Да!/Нет!») → `POST /api/elections/initiate`.
- Мини-таблица `shared/components/election-table` над полем ввода: счётчик «Проголосовали X/Y жителей», таймер окончания, 5 слотов, «Выдвинуть свою кандидатуру»/«Проголосовать», результат после закрытия. Обновляется поллингом `overview` (8 с).
- Модалка уведомлений: история из REST + live через WS `/user/queue/notifications`; по типам `ELECTION_STARTED`/`ELECTION_RESULT`/`APPLICATION_RESULT`.
- Модалка «Информация о районе» → «Мэрия» показывает реального губернатора/мэра/депутатов из `LocationPost`.

### Сервисы/модели фронта
`election.service`, `notification.service` (+live WS), `location-post.service`; модели `models/poll/election.interface.ts`, `models/notification/*`, `models/location-post/*`.

### Настройки района (админская панель)
- Хранятся пер-районно в БД (`district_settings`), дефолты проставляются при создании района; отдельного `application.yaml` для них нет.
- API: `GET`/`PUT /api/districts/{id}/settings`.
- UI: вкладка «Настройки района» (🛠️) в nav-rail → `DistrictSettingsModal`; группы «Выборы губернатора» и «Обжаловать губернатора…».
- `PollService.createGovernorElection` и `ElectionFacade` читают длительность/окно «живого»/кворум/число слотов из этих настроек (для будущих выборов).

### Известные ограничения / дыры (не входили в эту итерацию)
- Кворум проверяется только при создании, но НЕ при закрытии: `ElectionResultHandlerAdapter` назначает победителя и без набора кворума (сценарий предусматривает «не назначать, если кворум не набран»).

