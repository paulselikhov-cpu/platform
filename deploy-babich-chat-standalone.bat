@echo off
chcp 65001 >nul
echo 🚀 Starting Babich Chat standalone deployment...
echo.

REM Проверяем Docker
echo 🔍 Checking Docker...
docker --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker not found! Please install Docker Desktop.
    pause
    exit /b 1
)
docker info >nul 2>&1
if errorlevel 1 (
    echo ❌ Docker is not running! Please start Docker Desktop.
    pause
    exit /b 1
)
echo ✅ Docker is running
echo.

REM Переходим в platform-ui
echo 📁 Changing to platform-ui folder...
cd platform-ui
if errorlevel 1 (
    echo ❌ platform-ui folder not found!
    pause
    exit /b 1
)
echo ✅ Folder found
echo.

REM Устанавливаем зависимости если нужно
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

REM Собираем standalone версию
echo 📦 Building babich-chat-ui standalone...
call npx ng run babich-chat-ui:esbuild-standalone:production
if errorlevel 1 (
    echo ❌ Failed to build babich-chat-ui standalone!
    echo.
    echo Try running manually:
    echo    cd platform-ui
    echo    npx ng run babich-chat-ui:esbuild-standalone:production
    pause
    exit /b 1
)
echo ✅ babich-chat-ui standalone build completed!
echo.

REM Проверяем билд
echo 🔍 Checking build output...
if exist dist\babich-chat-standalone\browser\index.html (
    echo ✅ Standalone build found at: dist\babich-chat-standalone\browser\
) else (
    echo ❌ Standalone build not found!
    echo Expected: dist\babich-chat-standalone\browser\index.html
    pause
    exit /b 1
)
echo.

REM Копируем в контейнер
echo 🐳 Copying to nginx container...
docker cp dist\babich-chat-standalone\browser\. babich-nginx:/usr/share/nginx/babich-chat/
if errorlevel 1 (
    echo ❌ Failed to copy files to container!
    echo    Make sure babich-nginx container is running.
    pause
    exit /b 1
)
echo ✅ Files copied to container
echo.

REM Перезагружаем nginx
echo 🔄 Reloading nginx...
docker exec babich-nginx nginx -s reload
if errorlevel 1 (
    echo ❌ Failed to reload nginx!
    pause
    exit /b 1
)
echo ✅ Nginx reloaded
echo.

cd ..

echo ==========================================
echo ✅ SUCCESS! Babich Chat standalone ready!
echo ==========================================
echo.
echo 🌐 Standalone: http://localhost/babich-chat/
echo 🌐 Via shell:  http://localhost/platform/chat
echo.
echo 📋 Useful commands:
echo    View logs:  docker logs babich-nginx
echo    Stop:       docker-compose down
echo ==========================================
pause