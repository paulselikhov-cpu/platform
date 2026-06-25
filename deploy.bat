@echo off
chcp 65001 >nul
echo 🚀 Starting Angular deployment...
echo.

REM Проверяем наличие Docker
echo 🔍 Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker not found! Please install Docker Desktop.
    echo    Download: https://www.docker.com/products/docker-desktop/
    echo.
    echo 💡 After installing Docker Desktop:
    echo    1. Restart your computer
    echo    2. Open Docker Desktop
    echo    3. Wait for Docker to start
    echo    4. Run this script again
    pause
    exit /b 1
)
echo ✅ Docker found
echo.

REM Проверяем запущен ли Docker
echo 🔍 Checking if Docker is running...
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running!
    echo    Please start Docker Desktop and wait for it to fully start.
    pause
    exit /b 1
)
echo ✅ Docker is running
echo.

REM Переходим в папку Angular
echo 📁 Changing to babich-chat-ui folder...
cd babich-chat/babich-chat-ui
if errorlevel 1 (
    echo ❌ babich-chat-ui folder not found!
    echo    Current directory: %cd%
    pause
    exit /b 1
)
echo ✅ Folder found
echo.

REM Проверяем наличие package.json
echo 🔍 Checking package.json...
if not exist package.json (
    echo ❌ package.json not found in babich-chat-ui folder!
    pause
    exit /b 1
)
echo ✅ package.json found
echo.

REM Проверяем наличие Angular CLI
echo 🔍 Checking Angular CLI...
call npx ng version >nul 2>&1
if errorlevel 1 (
    echo 📦 Installing Angular CLI...
    call npm install -g @angular/cli
    if errorlevel 1 (
        echo ❌ Failed to install Angular CLI!
        pause
        exit /b 1
    )
)
echo ✅ Angular CLI available
echo.

REM Устанавливаем зависимости (если нет node_modules)
if not exist node_modules (
    echo 📦 Installing dependencies...
    call npm install
    if errorlevel 1 (
        echo ❌ Failed to install dependencies!
        pause
        exit /b 1
    )
    echo ✅ Dependencies installed
) else (
    echo ✅ node_modules already exists
)
echo.

REM Собираем Angular
echo 📦 Building Angular application...
echo Command: ng build --configuration=production
call npx ng build --configuration=production
if errorlevel 1 (
    echo ❌ Failed to build Angular application!
    echo.
    echo Try running manually:
    echo    cd babich-chat-ui
    echo    npx ng build --configuration=production
    pause
    exit /b 1
)
echo ✅ Build completed successfully!
echo.

REM Проверяем наличие собранных файлов
echo 🔍 Checking build output...
if exist dist\babich-chat-ui\browser\index.html (
    echo ✅ Built files found at: dist\babich-chat-ui\browser\
) else (
    echo ❌ Built files not found!
    echo Expected: dist\babich-chat-ui\browser\index.html
    echo Actual files:
    dir dist\babich-chat-ui\
    pause
    exit /b 1
)
echo.

REM Возвращаемся в корень
cd ..
echo 📁 Returned to root folder
echo.

REM Запускаем Docker Compose
echo 🐳 Starting Docker containers...
echo Command: docker-compose up -d --build
docker-compose up -d --build
if errorlevel 1 (
    echo ❌ Failed to start Docker containers!
    echo.
    echo Check docker-compose.yml syntax:
    docker-compose config
    pause
    exit /b 1
)
echo.

REM Даем время контейнерам запуститься
echo ⏳ Waiting for containers to start...
timeout /t 3 /nobreak >nul

REM Проверяем статус контейнеров
echo 🔍 Container status:
docker-compose ps
echo.

REM Проверяем, что сайт отвечает
echo 🔍 Testing website...
curl -s -o nul -w "%%{http_code}" http://localhost > status.txt
set /p HTTP_STATUS=<status.txt
del status.txt
if "%HTTP_STATUS%"=="200" (
    echo ✅ Website is responding with status 200
) else (
    echo ⚠️ Website returned status: %HTTP_STATUS%
    echo    Try checking logs: docker-compose logs nginx
)

echo.

echo ==========================================
echo ✅ SUCCESS! Application is ready!
echo ==========================================
echo.
echo 🌐 Frontend: http://localhost
echo 📡 API:      http://localhost/api/users
echo 📊 Database: localhost:5432
echo.
echo 📋 Useful commands:
echo    View logs:  docker-compose logs -f
echo    Stop:       docker-compose down
echo    Restart:    docker-compose restart
echo.
echo 📂 Build folder: babich-chat-ui/dist/babich-chat-ui/browser/
echo ==========================================
pause