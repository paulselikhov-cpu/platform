# Команды проекта BabichChat

## Shell
Все команды выполняются в **git bash (MINGW64)**. `&&` работает для chaining.

## Backend (babich-app — Java / Spring Boot)

```bash
# Сборка проекта
cd babich-app && mvn clean install -DskipTests

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

## Frontend (babich-app — второй Angular проект, если есть)

```bash
cd babich-app && npm install
cd babich-app && npm run start
```

## Инфраструктура (Docker)

```bash
# Запуск всех контейнеров (nginx, БД, Redis и т.д.)
docker-compose up -d

# Остановка
docker-compose down

# Просмотр логов
docker-compose logs -f
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
