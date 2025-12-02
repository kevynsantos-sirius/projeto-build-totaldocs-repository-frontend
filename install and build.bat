@echo off
setlocal enabledelayedexpansion

:: ========================================
:: Carregar variáveis do build.properties
:: ========================================
for /f "tokens=1,2 delims==" %%a in (build.properties) do (
    set "%%a=%%b"
)

:: ========================================
:: Normalizar ROOT_PATH
:: ========================================
pushd "%~dp0%ROOT_PATH%" >nul
set "ROOT_PATH=%cd%"
popd >nul

:: Definir caminhos absolutos
set "FRONTEND_PATH=%ROOT_PATH%\%FRONTEND_DIR%"
set "NGINX_PATH=%ROOT_PATH%\%NGINX_DIR%"
set "ACOPLADO_PATH=%FRONTEND_PATH%\node_modules\%ACOPLADO_DIR%"
set "LOCALIZE_CORE_PATH=%FRONTEND_PATH%\node_modules\%LOCALIZE_CORE_DIR%"
set "MENU_PATH=%FRONTEND_PATH%\node_modules\%MENU_DIR%"

echo ========================================
echo [INFO] Iniciando build
echo ROOT_PATH            = %ROOT_PATH%
echo FRONTEND_DIR         = %FRONTEND_DIR%
echo NGINX_DIR            = %NGINX_DIR%
echo ACOPLADO_DIR         = %ACOPLADO_DIR%
echo LOCALIZE_CORE_DIR    = %LOCALIZE_CORE_DIR%
echo MENU_DIR             = %MENU_DIR%
echo GIT_HASH             = %GIT_HASH%
echo LOCALIZE_CORE_HASH   = %LOCALIZE_CORE_HASH%
echo MENU_HASH            = %MENU_HASH%
echo FRONTEND_PATH        = %FRONTEND_PATH%
echo NGINX_PATH           = %NGINX_PATH%
echo ACOPLADO_PATH        = %ACOPLADO_PATH%
echo LOCALIZE_CORE_PATH   = %LOCALIZE_CORE_PATH%
echo MENU_PATH            = %MENU_PATH%
echo ========================================

:: ========================================
:: 1. Atualizar projeto ACOPLADO
:: ========================================
if exist "%ACOPLADO_PATH%" (
    echo [INFO] Removendo projeto acoplado antigo...
    rmdir /s /q "%ACOPLADO_PATH%"
)

echo [INFO] Instalando projeto acoplado do GitHub...
cd /d "%FRONTEND_PATH%"
call npm install git+https://github.com/kevynsantos-sirius/%ACOPLADO_DIR%#%GIT_HASH%
if errorlevel 1 exit /b 1

cd /d "%ACOPLADO_PATH%"
call npm install || exit /b 1
call npx tsc || exit /b 1
call npm run build || exit /b 1
cd /d "%FRONTEND_PATH%"

:: ========================================
:: 1.1 Atualizar projeto LOCALIZE CORE
:: ========================================
if exist "%LOCALIZE_CORE_PATH%" (
    echo [INFO] Removendo projeto localize-core antigo...
    rmdir /s /q "%LOCALIZE_CORE_PATH%"
)

echo [INFO] Instalando totaldocs-message-localize-core...
cd /d "%FRONTEND_PATH%"
call npm install git+https://git-codecommit.us-east-1.amazonaws.com/v1/repos/%LOCALIZE_CORE_DIR%
if errorlevel 1 exit /b 1

cd /d "%LOCALIZE_CORE_PATH%"
call npm install || exit /b 1
call npx tsc || exit /b 1
call npm run build || exit /b 1
cd /d "%FRONTEND_PATH%"

:: ========================================
:: 1.2 NOVO PROJETO ACOPLADO: MENU
:: ========================================
if exist "%MENU_PATH%" (
    echo [INFO] Removendo projeto totaldocs-menu antigo...
    rmdir /s /q "%MENU_PATH%"
)

echo [INFO] Instalando totaldocs-menu...
cd /d "%FRONTEND_PATH%"
call npm install git+https://git-codecommit.us-east-1.amazonaws.com/v1/repos/%MENU_DIR%#%MENU_HASH%
if errorlevel 1 (
    echo [ERRO] Falha no npm install do totaldocs-menu
    exit /b 1
)

cd /d "%MENU_PATH%"
call npm install
if errorlevel 1 (
    echo [ERRO] Falha no npm install dentro do projeto totaldocs-menu
    exit /b 1
)

call npx tsc
if errorlevel 1 (
    echo [ERRO] Falha no tsc do totaldocs-menu
    exit /b 1
)

call npm run build
if errorlevel 1 (
    echo [ERRO] Falha no build do totaldocs-menu
    exit /b 1
)
cd /d "%FRONTEND_PATH%"

:: ========================================
:: 2. Build do frontend
:: ========================================
echo [INFO] Instalando dependências do frontend...
call npm install || exit /b 1

echo [INFO] Gerando build do frontend...
call npm run build || exit /b 1

:: ========================================
:: 3. Copiar build para nginx
:: ========================================
echo [INFO] Verificando pasta dist...
if not exist "%FRONTEND_PATH%\dist" exit /b 1

xcopy /s /e /y "%FRONTEND_PATH%\dist" "%NGINX_PATH%\frontend\dist\%FRONTEND_DIR%\" || exit /b 1

:: ========================================
:: 4. Restart Docker
:: ========================================
docker rm -f nginx-react-struts
cd /d "%NGINX_PATH%"
docker run --name nginx-react-struts ^
-v "%NGINX_PATH%\frontend\dist:/usr/share/nginx/html" ^
-v "%NGINX_PATH%\nginx.conf:/etc/nginx/nginx.conf" ^
-p 80:80 -d nginx || exit /b 1

:: ========================================
:: 5. Finalizado
:: ========================================
echo ========================================
echo [SUCESSO] Build e deploy finalizado
echo ========================================
pause
exit /b 0
