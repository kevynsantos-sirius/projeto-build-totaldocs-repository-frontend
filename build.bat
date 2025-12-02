@echo off
setlocal enabledelayedexpansion

:: ========================================
:: Perguntar se deseja instalar algum projeto extra
:: ========================================
echo.
echo ========================================
echo Deseja atualizar algum projeto especifico?
echo (Pressione ENTER para pular)
echo.
echo Opcoes:
echo   1 - totaldocs-oauth2-handler
echo   2 - totaldocs-message-localize-core
echo   3 - totaldocs-menu-frontend
echo ========================================
set /p CUSTOM_CHOICE="Escolha (1/2/3 ou ENTER): "

set "CUSTOM_PROJECT="

if "%CUSTOM_CHOICE%"=="1" set "CUSTOM_PROJECT=oauth"
if "%CUSTOM_CHOICE%"=="2" set "CUSTOM_PROJECT=core"
if "%CUSTOM_CHOICE%"=="3" set "CUSTOM_PROJECT=menu"

echo Escolhido: %CUSTOM_PROJECT%
echo.

:: ========================================
:: Carregar variaveis do build.properties
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

:: Definir caminhos
set "FRONTEND_PATH=%ROOT_PATH%\%FRONTEND_DIR%"
set "NGINX_PATH=%ROOT_PATH%\%NGINX_DIR%"
set "ACOPLADO_PATH=%FRONTEND_PATH%\node_modules\%ACOPLADO_DIR%"
set "LOCALIZE_CORE_PATH=%FRONTEND_PATH%\node_modules\%LOCALIZE_CORE_DIR%"
set "MENU_PATH=%FRONTEND_PATH%\node_modules\%MENU_DIR%"

echo ========================================
echo [INFO] Iniciando build
echo ========================================

cd /d "%FRONTEND_PATH%"

:: ========================================
:: 0. Executar build do projeto escolhido pelo usuário (opcional)
:: ========================================
if NOT "%CUSTOM_PROJECT%"=="" (

    if "%CUSTOM_PROJECT%"=="oauth" (
        echo [INFO] Atualizando totaldocs-oauth2-handler...
        if exist "%ACOPLADO_PATH%" rmdir /s /q "%ACOPLADO_PATH%"
        call npm install git+https://github.com/kevynsantos-sirius/%ACOPLADO_DIR%#%GIT_HASH% || exit /b 1
        cd /d "%ACOPLADO_PATH%"
        call npm install || exit /b 1
        call npx tsc || exit /b 1
        call npm run build || exit /b 1
        cd /d "%FRONTEND_PATH%"
    )

    if "%CUSTOM_PROJECT%"=="core" (
        echo [INFO] Atualizando totaldocs-message-localize-core...
        if exist "%LOCALIZE_CORE_PATH%" rmdir /s /q "%LOCALIZE_CORE_PATH%"
        call npm install git+https://git-codecommit.us-east-1.amazonaws.com/v1/repos/%LOCALIZE_CORE_DIR% || exit /b 1
        cd /d "%LOCALIZE_CORE_PATH%"
        call npm install || exit /b 1
        call npx tsc || exit /b 1
        call npm run build || exit /b 1
        cd /d "%FRONTEND_PATH%"
    )

    if "%CUSTOM_PROJECT%"=="menu" (
        echo [INFO] Atualizando totaldocs-menu-frontend...
        if exist "%MENU_PATH%" rmdir /s /q "%MENU_PATH%"
        call npm install git+https://git-codecommit.us-east-1.amazonaws.com/v1/repos/%MENU_DIR%#%MENU_HASH% || exit /b 1
        cd /d "%MENU_PATH%"
        call npm install || exit /b 1
        call npx tsc || exit /b 1
        call npm run build || exit /b 1
        cd /d "%FRONTEND_PATH%"
    )

) else (
    echo [INFO] Nenhum projeto externo selecionado. Pulando atualizacoes acopladas...
)

:: ========================================
:: 2. Build do frontend
:: ========================================
echo [INFO] Instalando dependencias do frontend...
call npm install || exit /b 1

echo [INFO] Gerando build do frontend...
call npm run build || exit /b 1

:: ========================================
:: 3. Copiar build
:: ========================================
echo [INFO] Copiando dist para nginx...
xcopy /s /e /y "%FRONTEND_PATH%\dist" "%NGINX_PATH%\frontend\dist\%FRONTEND_DIR%\" || exit /b 1

:: ========================================
:: 4. Docker
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
