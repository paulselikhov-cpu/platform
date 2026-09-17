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
cd babich-app && mvn test -Dtest=TestClassName
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

## Процессы и порты

```bash
# Проверить какой процесс на порту 8080
netstat -ano | grep :8080

# Принудительно убить все java-процессы (кроме IntelliJ)
taskkill //F //IM java.exe //FI "PID ne $(ps -W | grep -i "idea\|intellij" | awk '{print $1}')"

# Убить конкретный процесс по PID
taskkill //PID <PID> //F
```
