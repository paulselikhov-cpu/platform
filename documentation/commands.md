# Команды проекта BabichChat

## Важно: Windows PowerShell
Команды `&&` не работают в PowerShell. Используйте `cmd /c "команда1 && команда2"` или разделяйте
команды точкой с запятой `;`.

## Backend (babich-app — Java / Spring Boot)

```bash
# Сборка проекта (PowerShell)
cd babich-app; mvn clean install -DskipTests

# или через cmd:
cmd /c "cd babich-app && mvn clean install -DskipTests"

# Запуск backend
cd babich-app; mvn spring-boot:run

# Запуск конкретного теста
cd babich-app; mvn test -Dtest=TestClassName
```

## Frontend (platform-ui — Angular)

```bash
# Установка зависимостей
cd platform-ui; npm install

# Запуск dev-сервера
cd platform-ui; npm run start

# Сборка
cd platform-ui; npx ng build --project babich-chat-ui

# или через cmd:
cmd /c "cd platform-ui && npx ng build --project babich-chat-ui 2>&1"
```

## Frontend (babich-app — второй Angular проект, если есть)

```bash
cd babich-app; npm install
cd babich-app; npm run start
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
cd platform-ui; npx ng generate component features/example/example-component
cd platform-ui; npx ng generate service services/example-service
cd platform-ui; npx ng generate interface models/example/example-model
```

## Git

```bash
# Статус
git status

# Добавить все изменения (только add, пушить нельзя — правило проекта)
git add -A