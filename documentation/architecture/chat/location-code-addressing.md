# Адресация локаций по code

Локация адресуется в URL и в бэкенд-запросах **кодом**, а не числовым `id`:

```
/chat/location/LENIN_SQUARE/main
/chat/location/LENIN_SQUARE/feature/election
/chat/location/IVAN_KVARTIRA/room/12
```

## Модель данных

`Location` (таблица `locations`):

| Поле | Назначение |
|---|---|
| `code` | адрес локации, `VARCHAR(50)`, `UNIQUE (district_id, code)` |
| `type` | классификация: `SYSTEM` / `DEFAULT` / `BUSINESS` |
| ~~`is_system`~~ | **удалён** — его роль выполняет `type` |

`LocationType` сокращён до трёх значений. Конкретная разновидность системной
локации задаётся `code`, а не `type`: константы в
`domain/location/enums/SystemLocationCode` (`CITY_HALL`, `LENIN_SQUARE`,
`POLICE_STATION`, `PRISON`, `BANK`, `WAREHOUSE`, `GENERAL_MARKET`,
`REAL_ESTATE_MARKET`), зеркально — `SystemLocationCode` в
`models/location/location-type.enum.ts`.

`District.systemLocations` помечен `@SQLRestriction("type = 'SYSTEM'")`.

## Почему уникальность составная

`UNIQUE (district_id, code)`, а не `UNIQUE (code)`: **район работает как «сервер»
в онлайн-игре**. У каждого района своя «Площадь Ленина» с тем же кодом, и
персонаж подключён ровно к одному району — перейти в другой район значит
войти другим персонажем.

Следствие, о котором важно помнить: **названия системных локаций совпадают
между районами**. Поэтому в UI нельзя дедуплицировать или искать локацию по
имени — только по `code`.

## Как резолвится район

Района в URL нет намеренно. `GET /api/locations/by-code/{code}?characterId=`
(`LocationService.getLocationForCode`) берёт район из персонажа
(`character.getDistrictId()`), а не из параметров запроса.

Это не удобство, а граница доступа: подставив чужой `districtId` в параметр,
нельзя было бы адресовать локацию чужого района. Поскольку района в URL нет,
такая подмена структурно невозможна.

## Код пользовательской локации

Игрок задаёт код сам в форме `/chat/location/create`
(`CreateLocationRequest.code` → `LocationService.normalizeLocationCode`):

- 3–50 символов, приводится к верхнему регистру (`ivan_kvartira` → `IVAN_KVARTIRA`);
- только `[A-Z0-9_]` — код попадает прямо в URL;
- не может совпадать с `SystemLocationCode` (иначе игрок занял бы код мэрии);
- уникален в пределах района.

Новые локации создаются с `type = DEFAULT`. `BUSINESS` зарезервирован под
будущий механизм заведений, `HomeFeature` его не реализует.

## Где ещё остался `id`

Внутрь локации (комнаты, участники, CRUD, `LocationUser`) код не заведён —
там работает `locationId` из уже загруженного `ILocation`. Это осознанно: смена
адреса в URL не должна тащить за собой переписывание внутренних API.
`GET /api/locations/{locationId}` сохранён именно для этого.

## Системные локации: кто их создаёт

Системные локации заводит **только `data.sql`** (`src/main/resources/data.sql`) —
8 локаций района `CENTRAL` с описаниями и 21 комнатой. Это единственное место:
там же лежат `location_templates`, `template_rooms` и сам район.

Районы кодом не создаются — их тоже вставляет `data.sql`.

Следствие: пока существует один район (`CENTRAL`), всё засеяно. Если появится
второй район, системные локации для него нужно будет завести там же или
завести отдельный идемпотентный сидер — но в одном месте, не в двух.

## Схема

Схемой управляет Hibernate: `spring.jpa.hibernate.ddl-auto=create` в
`application.yaml`. Отдельных SQL-миграций в проекте нет и не нужно — при
создании таблица `locations` собирается из entity, а данные заливает
`data.sql`.

Следствие для разработки: база пересоздаётся на каждом старте, поэтому
`UNIQUE (district_id, code)` всегда в силе и «унаследованных» данных с
старой схемой не бывает.
