# Команды проекта BabichChat

## Backend (babich-app — Java / Spring Boot)

```bash
# Сборка проекта
cd babich-app && mvn clean install -DskipTests

# Запуск backend
cd babich-app && mvn spring-boot:run

# Запуск конкретного теста
cd babich-app && mvn test -Dtest=TestClassName
```

## Frontend (platform-ui — Angular)

```bash
# Установка зависимостей
cd platform-ui && npm install

# Запуск dev-сервера
cd platform-ui && npm run start
# или
cd platform-ui && npx ng serve

# Сборка
cd platform-ui && npm run build
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

# Коммит
git add -A && git commit -m "message"