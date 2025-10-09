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

:: Definir demais caminhos absolutos
set "FRONTEND_PATH=%ROOT_PATH%\%FRONTEND_DIR%"
set "NGINX_PATH=%ROOT_PATH%\%NGINX_DIR%"
set "ACOPLADO_PATH=%FRONTEND_PATH%\node_modules\%ACOPLADO_DIR%"
set "LOCALIZE_CORE_PATH=%FRONTEND_PATH%\node_modules\%LOCALIZE_CORE_DIR%"

echo ========================================
echo [INFO] Iniciando build
echo ROOT_PATH    = %ROOT_PATH%
echo FRONTEND_DIR = %FRONTEND_DIR%
echo NGINX_DIR    = %NGINX_DIR%
echo ACOPLADO_DIR = %ACOPLADO_DIR%
echo LOCALIZE_CORE_DIR = %LOCALIZE_CORE_DIR%
echo GIT_HASH     = %GIT_HASH%
echo LOCALIZE_CORE_HASH = %LOCALIZE_CORE_HASH%
echo FRONTEND_PATH= %FRONTEND_PATH%
echo NGINX_PATH   = %NGINX_PATH%
echo ACOPLADO_PATH= %ACOPLADO_PATH%
echo LOCALIZE_CORE_PATH = %LOCALIZE_CORE_PATH%
echo ========================================

:: ========================================
:: 1. Atualizar projeto acoplado
:: ========================================
if exist "%ACOPLADO_PATH%" (
    echo [INFO] Removendo projeto acoplado antigo...
    rmdir /s /q "%ACOPLADO_PATH%"
)

echo [INFO] Instalando projeto acoplado do GitHub...
cd /d "%FRONTEND_PATH%"
call npm install git+https://github.com/kevynsantos-sirius/%ACOPLADO_DIR%#%GIT_HASH%
if errorlevel 1 (
    echo [ERRO] Falha no npm install do projeto acoplado
    exit /b 1
)

cd /d "%ACOPLADO_PATH%"
call npm install
if errorlevel 1 (
    echo [ERRO] Falha no npm install dentro do projeto acoplado
    exit /b 1
)

call npx tsc
if errorlevel 1 (
    echo [ERRO] Falha no tsc do projeto acoplado
    exit /b 1
)

call npm run build
if errorlevel 1 (
    echo [ERRO] Falha no build do projeto acoplado
    exit /b 1
)
cd /d "%FRONTEND_PATH%"

:: ========================================
:: 1.1. Atualizar projeto totaldocs-message-localize-core do AWS CodeCommit
:: ========================================
if exist "%LOCALIZE_CORE_PATH%" (
    echo [INFO] Removendo projeto localize-core antigo...
    rmdir /s /q "%LOCALIZE_CORE_PATH%"
)

echo [INFO] Instalando projeto totaldocs-message-localize-core do AWS CodeCommit...
cd /d "%FRONTEND_PATH%"
call npm install git+https://git-codecommit.us-east-1.amazonaws.com/v1/repos/%LOCALIZE_CORE_DIR%
if errorlevel 1 (
    echo [ERRO] Falha no npm install do totaldocs-message-localize-core
    exit /b 1
)

cd /d "%LOCALIZE_CORE_PATH%"
call npm install
if errorlevel 1 (
    echo [ERRO] Falha no npm install dentro do projeto totaldocs-message-localize-core
    exit /b 1
)

call npx tsc
if errorlevel 1 (
    echo [ERRO] Falha no tsc do totaldocs-message-localize-core
    exit /b 1
)

call npm run build
if errorlevel 1 (
    echo [ERRO] Falha no build do totaldocs-message-localize-core
    exit /b 1
)
cd /d "%FRONTEND_PATH%"

:: ========================================
:: 2. Build do frontend principal
:: ========================================
echo [INFO] Instalando dependências do frontend...
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
:: 3. Copiar build para o projeto nginx
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
:: 4. Restart do Docker
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
:: 5. Finalização
:: ========================================
echo ========================================
echo [SUCESSO] Build e deploy finalizado
echo ========================================
pause
exit /b 0