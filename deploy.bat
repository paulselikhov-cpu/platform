@echo off
chcp 65001 >nul
echo 🚀 Starting Platform + Chat (Federation) deployment...
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

REM 1) Собираем babich-chat-ui (remote для Federation)
echo 📦 [1/2] Building babich-chat-ui (federation remote)...
call npx ng run babich-chat-ui:build:production
if errorlevel 1 (
    echo ❌ Failed to build babich-chat-ui!
    echo.
    echo Try running manually:
    echo    cd platform-ui
    echo    npx ng run babich-chat-ui:build:production
    pause
    exit /b 1
)
echo ✅ babich-chat-ui build completed!
echo.

REM 2) Собираем platform (shell)
echo 📦 [2/2] Building platform (shell)...
call npx ng run platform:build:production
if errorlevel 1 (
    echo ❌ Failed to build platform!
    echo.
    echo Try running manually:
    echo    cd platform-ui
    echo    npx ng run platform:build:production
    pause
    exit /b 1
)
echo ✅ platform build completed!
echo.

REM Проверяем билды
echo 🔍 Checking build outputs...
if exist dist\babich-chat-ui\browser\index.html (
    echo ✅ Chat build found at: dist\babich-chat-ui\browser\
) else (
    echo ❌ Chat build not found!
    echo Expected: dist\babich-chat-ui\browser\index.html
    pause
    exit /b 1
)
if exist dist\platform\browser\index.html (
    echo ✅ Platform build found at: dist\platform\browser\
) else (
    echo ❌ Platform build not found!
    echo Expected: dist\platform\browser\index.html
    pause
    exit /b 1
)
echo.

REM Копируем оба в контейнер
echo 🐳 Copying to nginx container...
docker cp dist\babich-chat-ui\browser\. babich-nginx:/usr/share/nginx/chat/
if errorlevel 1 (
    echo ❌ Failed to copy chat files to container!
    echo    Make sure babich-nginx container is running.
    pause
    exit /b 1
)
echo ✅ Chat files copied

docker cp dist\platform\browser\. babich-nginx:/usr/share/nginx/platform/
if errorlevel 1 (
    echo ❌ Failed to copy platform files to container!
    pause
    exit /b 1
)
echo ✅ Platform files copied
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
echo ✅ SUCCESS! Platform + Chat ready!
echo ==========================================
echo.
echo 🌐 Platform:  http://localhost/platform/
echo 🌐 Chat:      http://localhost/platform/chat
echo.
echo 📋 Useful commands:
echo    View logs:  docker logs babich-nginx
echo    Stop:       docker-compose down
echo ==========================================
pause