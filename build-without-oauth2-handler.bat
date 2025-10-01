@echo off
setlocal enabledelayedexpansion

:: ========================================
:: Carregar variáveis do build.properties
:: ========================================
for /f "tokens=1,2 delims==" %%a in (build.properties) do (
    set "%%a=%%b"
)

:: ========================================
:: Normalizar ROOT_PATH (resolvendo .. ou caminhos relativos)
:: ========================================
pushd "%~dp0%ROOT_PATH%" >nul
set "ROOT_PATH=%cd%"
popd >nul

:: Definir caminhos absolutos
set "FRONTEND_PATH=%ROOT_PATH%\%FRONTEND_DIR%"
set "NGINX_PATH=%ROOT_PATH%\%NGINX_DIR%"

echo ========================================
echo [INFO] Iniciando build (SEM ACOPLADO)
echo ROOT_PATH    = %ROOT_PATH%
echo FRONTEND_DIR = %FRONTEND_DIR%
echo NGINX_DIR    = %NGINX_DIR%
echo GIT_HASH     = %GIT_HASH%
echo FRONTEND_PATH= %FRONTEND_PATH%
echo NGINX_PATH   = %NGINX_PATH%
echo ========================================

:: ========================================
:: 1. Build do frontend principal
:: ========================================
echo [INFO] Instalando dependências do frontend...
cd /d "%FRONTEND_PATH%"
call npm install
if errorlevel 1 (
    echo [ERRO] Falha no npm install do frontend
    exit /b 1
)

echo [INFO] Gerando build do frontend...
call npm run build
if errorlevel 1 (
    echo [ERRO] Falha no npm run build do frontend
    exit /b 1
)

:: ========================================
:: 2. Copiar build para o projeto nginx
:: ========================================
echo [INFO] Verificando pasta dist em "%FRONTEND_PATH%\dist"...
if not exist "%FRONTEND_PATH%\dist" (
    echo [ERRO] Pasta dist não encontrada em "%FRONTEND_PATH%\dist"
    exit /b 1
)

echo [INFO] Copiando dist para "%NGINX_PATH%\frontend\dist\%FRONTEND_DIR%"...
xcopy /s /e /y "%FRONTEND_PATH%\dist" "%NGINX_PATH%\frontend\dist\%FRONTEND_DIR%\" 
if errorlevel 1 (
    echo [ERRO] Falha ao copiar arquivos dist
    exit /b 1
)

:: ========================================
:: 3. Restart do Docker
:: ========================================
echo [INFO] Removendo container antigo...
docker rm -f nginx-react-struts

echo [INFO] Subindo novo container...
cd /d "%NGINX_PATH%"
docker run --name nginx-react-struts ^
-v "%NGINX_PATH%\frontend\dist:/usr/share/nginx/html" ^
-v "%NGINX_PATH%\nginx.conf:/etc/nginx/nginx.conf" ^
-p 80:80 -d nginx
if errorlevel 1 (
    echo [ERRO] Falha ao subir container docker
    exit /b 1
)

:: ========================================
:: 4. Finalização
:: ========================================
echo ========================================
echo [SUCESSO] Build e deploy finalizado (SEM ACOPLADO)
echo ========================================
pause
exit /b 0
