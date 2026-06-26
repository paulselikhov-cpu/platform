@echo off
chcp 65001 >nul
echo 🚀 Starting Angular deployment (two apps)...
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

REM ### ИЗМЕНЕНО: Переходим в папку platform-ui
echo 📁 Changing to platform-ui folder...
cd platform-ui
if errorlevel 1 (
    echo ❌ platform-ui folder not found!
    echo    Current directory: %cd%
    pause
    exit /b 1
)
echo ✅ Folder found
echo.

REM Проверяем наличие package.json
echo 🔍 Checking package.json...
if not exist package.json (
    echo ❌ package.json not found in platform-ui folder!
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

REM Собираем два приложения с разными base-href ###
echo 📦 Building Angular applications...
echo.
echo 1) Building babich-chat-ui (base-href=/chat/)...
call npx ng run babich-chat-ui:build:production -- --base-href=/chat/
if errorlevel 1 (
    echo ❌ Failed to build babich-chat-ui!
    echo.
    echo Try running manually:
    echo    cd platform-ui
    echo    npx ng run babich-chat-ui:build:production -- --base-href=/chat/
    pause
    exit /b 1
)
echo ✅ babich-chat-ui build completed!
echo.
echo 2) Building platform (base-href=/platform/)...
call npx ng run platform:build:production -- --base-href=/platform/
if errorlevel 1 (
    echo ❌ Failed to build platform!
    echo.
    echo Try running manually:
    echo    cd platform-ui
    echo    npx ng run platform:build:production -- --base-href=/platform/
    pause
    exit /b 1
)
echo ✅ platform build completed!
echo.

REM Проверяем наличие выходных файлов для обоих приложений ###
echo 🔍 Checking build outputs...
set CHAT_INDEX=dist\babich-chat-ui\browser\index.html
set PLATFORM_INDEX=dist\platform\browser\index.html
if exist %CHAT_INDEX% (
    echo ✅ Chat built files found at: dist\babich-chat-ui\browser\
) else (
    echo ❌ Chat built files not found!
    echo Expected: %CHAT_INDEX%
    echo Actual files in dist:
    dir dist\
    pause
    exit /b 1
)
if exist %PLATFORM_INDEX% (
    echo ✅ Platform built files found at: dist\platform\browser\
) else (
    echo ❌ Platform built files not found!
    echo Expected: %PLATFORM_INDEX%
    echo Actual files in dist:
    dir dist\
    pause
    exit /b 1
)
echo.

REM Возвращаемся в корень (откуда был запущен скрипт)
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

REM Проверяем доступность обоих приложений ###
echo 🔍 Testing websites...
set CHAT_STATUS=000
set PLATFORM_STATUS=000

curl -s -o nul -w "%%{http_code}" http://localhost/chat > chat_status.txt
set /p CHAT_STATUS=<chat_status.txt
del chat_status.txt

curl -s -o nul -w "%%{http_code}" http://localhost/platform > platform_status.txt
set /p PLATFORM_STATUS=<platform_status.txt
del platform_status.txt

if "%CHAT_STATUS%"=="200" (
    echo ✅ Chat is responding with status 200
) else (
    echo ⚠️ Chat returned status: %CHAT_STATUS%
    echo    Try checking logs: docker-compose logs nginx
)
if "%PLATFORM_STATUS%"=="200" (
    echo ✅ Platform is responding with status 200
) else (
    echo ⚠️ Platform returned status: %PLATFORM_STATUS%
    echo    Try checking logs: docker-compose logs nginx
)

echo.

echo ==========================================
echo ✅ SUCCESS! Applications are ready!
echo ==========================================
echo.
echo 🌐 Chat:      http://localhost/chat
echo 🌐 Platform:  http://localhost/platform
echo 📡 API:      http://localhost/api/users   (if configured)
echo 📊 Database: localhost:5432 (if used)
echo.
echo 📋 Useful commands:
echo    View logs:  docker-compose logs -f
echo    Stop:       docker-compose down
echo    Restart:    docker-compose restart
echo.
echo 📂 Build folders:
echo    Chat:      platform-ui/dist/babich-chat-ui/browser/
echo    Platform:  platform-ui/dist/platform/browser/
echo ==========================================
pause