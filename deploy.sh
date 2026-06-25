#!/bin/bash

# Устанавливаем кодировку UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

echo "🚀 Starting Angular deployment..."
echo ""

# Проверяем наличие Docker
echo "🔍 Checking Docker..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found! Please install Docker."
    echo "   Download: https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "💡 After installing Docker:"
    echo "   1. Restart your computer"
    echo "   2. Open Docker Desktop"
    echo "   3. Wait for Docker to start"
    echo "   4. Run this script again"
    read -p "Press Enter to exit..."
    exit 1
fi
echo "✅ Docker found"
echo ""

# Проверяем запущен ли Docker
echo "🔍 Checking if Docker is running..."
if ! docker info &> /dev/null; then
    echo "❌ Docker is not running!"
    echo "   Please start Docker Desktop and wait for it to fully start."
    read -p "Press Enter to exit..."
    exit 1
fi
echo "✅ Docker is running"
echo ""

# Переходим в папку Angular
echo "📁 Changing to babich-ui folder..."
if [ ! -d "babich-ui" ]; then
    echo "❌ babich-ui folder not found!"
    echo "   Current directory: $(pwd)"
    read -p "Press Enter to exit..."
    exit 1
fi
cd babich-ui || exit 1
echo "✅ Folder found"
echo ""

# Проверяем наличие package.json
echo "🔍 Checking package.json..."
if [ ! -f "package.json" ]; then
    echo "❌ package.json not found in babich-ui folder!"
    read -p "Press Enter to exit..."
    exit 1
fi
echo "✅ package.json found"
echo ""

# Проверяем наличие Angular CLI
echo "🔍 Checking Angular CLI..."
if ! npx ng version &> /dev/null; then
    echo "📦 Installing Angular CLI..."
    if ! npm install -g @angular/cli &> /dev/null; then
        echo "❌ Failed to install Angular CLI!"
        read -p "Press Enter to exit..."
        exit 1
    fi
fi
echo "✅ Angular CLI available"
echo ""

# Устанавливаем зависимости (если нет node_modules)
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    if ! npm install; then
        echo "❌ Failed to install dependencies!"
        read -p "Press Enter to exit..."
        exit 1
    fi
    echo "✅ Dependencies installed"
else
    echo "✅ node_modules already exists"
fi
echo ""

# Собираем Angular
echo "📦 Building Angular application..."
echo "Command: ng build --configuration=production"
if ! npx ng build --configuration=production; then
    echo "❌ Failed to build Angular application!"
    echo ""
    echo "Try running manually:"
    echo "   cd babich-ui"
    echo "   npx ng build --configuration=production"
    read -p "Press Enter to exit..."
    exit 1
fi
echo "✅ Build completed successfully!"
echo ""

# Проверяем наличие собранных файлов
echo "🔍 Checking build output..."
if [ -f "dist/babich-ui/browser/index.html" ]; then
    echo "✅ Built files found at: dist/babich-ui/browser/"
else
    echo "❌ Built files not found!"
    echo "Expected: dist/babich-ui/browser/index.html"
    echo "Actual files:"
    ls -la dist/babich-ui/
    read -p "Press Enter to exit..."
    exit 1
fi
echo ""

# Возвращаемся в корень
cd ..
echo "📁 Returned to root folder"
echo ""

# Запускаем Docker Compose
echo "🐳 Starting Docker containers..."
echo "Command: docker-compose up -d --build"
if ! docker-compose up -d --build; then
    echo "❌ Failed to start Docker containers!"
    echo ""
    echo "Check docker-compose.yml syntax:"
    docker-compose config
    read -p "Press Enter to exit..."
    exit 1
fi
echo ""

# Проверяем статус контейнеров
echo "🔍 Container status:"
docker-compose ps
echo ""

echo "=========================================="
echo "✅ SUCCESS! Application is ready!"
echo "=========================================="
echo ""
echo "🌐 Frontend: http://localhost"
echo "📡 API:      http://localhost/api/users"
echo "📊 Database: localhost:5432"
echo ""
echo "📋 Useful commands:"
echo "   View logs:  docker-compose logs -f"
echo "   Stop:       docker-compose down"
echo "   Restart:    docker-compose restart"
echo "=========================================="
read -p "Press Enter to exit..."