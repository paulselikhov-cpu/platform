# Реактивное обновление персонажа (без F5)

> Как реализовано: сервер сам пушит факт изменения персонажа, фронт
> перезагружает `currentChatUser` без F5.

## Проблема

Каждый клиент держит собственный локальный сигнал `currentChatUser`
(`CurrentChatUserService`). Изменения на сервере (одобрение заявки,
админская правка) не доходили до открытых SPA-вкладок до перезагрузки
страницы.

## Бэкенд

1. **Событие** `CharacterUpdatedEvent` (`core.event`, `EventType.CHARACTER_UPDATED`):
   - зарегистрировано в `@JsonSubTypes` базового `DomainEvent` (нужно для
     replay из `event_publication`);
   - `targetId = scopeId = characterId` (внутренний ChatUser.id);
   - payload пуст — слушателю достаточно id, полный профиль фронт
     перезапрашивает сам по REST.
2. **Публикация**: `ApplicationService.resolve()` публикует событие в той же
   транзакции, что и применение последствий заявки (`handler.handle()` +
   `save`), — только для заявок, меняющих ChatUser (паспорт, лицензия).
3. **Подписчик** `CharacterUpdatedListener` (модуль notification,
   `@ApplicationModuleListener` — AFTER_COMMIT + outbox-гарантии Modulith):
   - по `characterId` находит `ChatUser` → у него есть `username`;
   - WS-пуш `SimpMessagingTemplate.convertAndSendToUser(username,
     "/queue/character-updated", new CharacterUpdatedResponse(character.getId()))`;
   - `CharacterUpdatedResponse` — record c одним полем `characterId`.

Адресация по `characterId` (не по User.id): у пользователя несколько
персонажей (по одному на район), обновляться должен только изменённый.

## Фронтенд

4. Подписка в `CurrentChatUserService` (root, живёт всё время):
   `stomp.topic<{characterId}>('/user/queue/character-updated')` → `refresh()`.
   Используется существующее WS-соединение (`StompConnectionService`), новое
   не создаётся.
5. Следствия автоматические (всё подписано на `currentChatUser`):
   - `CharacterPanel` (монеты/энергия/XP/паспорт/лицензия/статус) обновляется
     у владельца;
   - роль → видимость пунктов nav-rail (в т.ч. «Настройки района») меняется
     реактивно;
   - уровень пересчитывается (XP → порог уровня на бэке).

## Связь с уведомлением о заявке

Параллельно в `/user/queue/notifications` уходит уведомление
APPLICATION_RESULT с контекстом `data={applicationType, applicationStatus}`
— фронт использует его для отображения в колокольчике и точечных реакций на
конкретный тип заявки. Канал `character-updated` — общий «факт изменения
профильных данных» и не требует разбора типа заявки на фронте.
