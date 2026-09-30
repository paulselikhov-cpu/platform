# Команды проекта BabichChat

## Shell
Все команды выполняются в **git bash (MINGW64)**. `&&` работает для chaining.

## Backend (babich-app — Java / Spring Boot)

```bash
# Сборка проекта
cd babich-app && mvn clean install -DskipTests

# Быстрая проверка компиляции (без полного clean install)
cd babich-app && mvn -q compile -DskipTests

# Запуск backend
cd babich-app && mvn spring-boot:run

# Запуск backend в фоне + хвост логов (30 секунд, потом автостоп)
cd babich-app && mvn spring-boot:run 2>&1 &
PID=$!; sleep 30; kill $PID 2>/dev/null; wait $PID 2>/dev/null

# Запуск конкретного теста
# ⚠️ ВНИМАНИЕ: `mvn test` БЕЗ переопределения ddl-auto СТИРАЕТ данные dev-БД chatdb.
#    @SpringBootTest поднимает контекст с application.yaml (ddl-auto: create) →
#    Hibernate пересоздаёт схему, data.sql накатывает только сиды
#    (1 район, 8 системных локаций, шаблоны). Аккаунты, персонажи, локации и
#    сообщения пользователя после такого прогона НЕ восстанавливаются.
#    Безопасные варианты — ниже (SPRING_JPA_HIBERNATE_DDL_AUTO=update или chatdb_test).
cd babich-app && mvn test -Dtest=TestClassName

# Прогон тестов без вайпа dev-БД: ddl-auto по умолчанию create — стирает таблицы.
# @SpringBootTest-тесты наследуют настройки application.yaml, поэтому переопределяем:
cd babich-app && SPRING_JPA_HIBERNATE_DDL_AUTO=update mvn test -Dtest=TestClassName

# Несколько тестов сразу (список в кавычках)
cd babich-app && SPRING_JPA_HIBERNATE_DDL_AUTO=update mvn test -Dtest='TestA,TestB,TestC'

# ПОЛНЫЙ прогон в изолированной БД — предпочтительнее варианта с ddl-auto=update:
# там тестовые строки оседают в dev-БД, а здесь chatdb вообще не трогается
# (ddl-auto=create пересоздаёт схему разовой chatdb_test).
docker exec babich-postgres psql -U chatuser -d postgres -c "CREATE DATABASE chatdb_test"
cd babich-app && SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/chatdb_test mvn -o test

# После переноса/переименования классов — только чистая сборка:
# инкрементальная компиляция оставляет старые .class в target/classes, и Spring
# падает на старте с ConflictingBeanDefinitionException (конфликт имён бинов,
# например applicationMessages из старого и нового пакета).
cd babich-app && mvn clean test -Dtest=TestClassName
```

### Запуск на другом порту без вайпа dev-БД

В `application.yaml` стоит `ddl-auto: create` — каждый старт **пересоздаёт таблицы** и стирает
данные. Если нужно просто проверить сборку/логику поверх существующих данных (или рядом уже
запущен бэкенд пользователя на 8080), переопределяем оба свойства через env:

```bash
cd babich-app && SERVER_PORT=8090 SPRING_JPA_HIBERNATE_DDL_AUTO=update mvn spring-boot:run

# в фоне, с логом в файл
cd babich-app && nohup env SERVER_PORT=8090 SPRING_JPA_HIBERNATE_DDL_AUTO=update mvn spring-boot:run > /d/babich/app-8090.log 2>&1 &

# погасить только свой инстанс (PID java-процесса слушающего 8090)
netstat -ano | grep ':8090 '
taskkill //PID <PID> //F
```

## Frontend (platform-ui — Angular)

```bash
# Установка зависимостей
cd platform-ui && npm install

# Запуск dev-сервера
cd platform-ui && npm run start

# Сборка
cd platform-ui && npx ng build --project babich-chat-ui
```

## Git

```bash
# Статус / диф / история
git status
git diff
git diff --stat
git log --oneline -10

# Добавить все изменения (только add, пушить нельзя — правило проекта)
git add -A
```

## Поиск по коду (быстрая навигация)

```bash
# Все классы модуля / списка файлов
find babich-app/src/main/java/com/platform/chat/modules -type f -name '*.java' | sort

# Где объявлена сущность / поле / эндпоинт
grep -rn "class ChatUser" babich-app/src/main/java --include='*.java'
grep -rn "@GetMapping\|@PostMapping" babich-app/src/main/java --include='*.java'
grep -rn "someSignal" platform-ui/projects/babich-chat-ui/src/app --include='*.ts'
```

## Инфраструктура (Docker)

```bash
# Запуск всех контейнеров (nginx, PostgreSQL, Redis)
docker-compose up -d

# Запуск только Redis (используется начиная с этапа R3, см.
# documentation/architecture/realtime/scale-targets-and-redis.md)
docker-compose up -d redis

# Остановка
docker-compose down

# Просмотр логов
docker-compose logs -f
```

## База данных (dev, PostgreSQL в Docker)

```bash
# Список таблиц
docker exec babich-postgres psql -U chatuser -d chatdb -c "\dt"

# Произвольный запрос
docker exec babich-postgres psql -U chatuser -d chatdb -c "select * from location_users order by id;"

# Удалить легаси-таблицы, оставшиеся от старой схемы.
# ddl-auto: create пересоздаёт только таблицы, замапленные в entity,
# поэтому старые таблицы (location_members, location_posts) висят в dev-БД вечно.
docker exec babich-postgres psql -U chatuser -d chatdb \
  -c "DROP TABLE IF EXISTS location_members;" -c "DROP TABLE IF EXISTS location_posts;"
```

## Генерация сущностей / компонентов (Angular)

```bash
cd platform-ui && npx ng generate component features/example/example-component
cd platform-ui && npx ng generate service services/example-service
cd platform-ui && npx ng generate interface models/example/example-model
```

## Git

```bash
# Статус
git status

# Добавить все изменения (только add, пушить нельзя — правило проекта)
git add -A
```

## Особенности окружения (Windows / git bash)

```bash
# `node` в этом git bash заалиасен на `winpty node.exe`, поэтому при перенаправлении
# вывода (`node script.cjs > out.log`) падает с "stdout is not a tty" и ничего не выполняет.
# Для скриптов/сборок, чей stdout уходит в файл или в pipe, вызывать node напрямую:
"/c/Program Files/nodejs/node.exe" script.cjs > out.log 2>&1
```

## Процессы и порты

```bash
# Проверить какой процесс на порту 8080
netstat -ano | grep :8080

# Принудительно убить все java-процессы (кроме IntelliJ)
taskkill //F //IM java.exe //FI "PID ne $(ps -W | grep -i "idea\|intellij" | awk '{print $1}')"

# Убить конкретный процесс по PID
taskkill //PID <PID> //F
```
