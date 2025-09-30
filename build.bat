@echo off
setlocal enabledelayedexpansion

REM ========================================
REM CONFIGURAÇÕES
REM ========================================

REM Caminho da pasta "projeto-build-totaldocs-repository-frontend" (onde está este .bat)
set ROOT_DIR=%~dp0

REM Caminhos relativos
set FRONTEND_DIR=%ROOT_DIR%totaldocs-repository-frontend
set NGINX_DIR=%ROOT_DIR%projeto-nginx - repositorio

REM Arquivo de propriedades
set PROPERTIES_FILE=%ROOT_DIR%build.properties

REM ========================================
REM LER HASH DO ARQUIVO build.properties
REM Exemplo do arquivo:
REM   GIT_HASH=0239bc770d74f1642c8e80fb7aeb4e9e257e4604
REM ========================================

set GIT_HASH=
for /f "tokens=1,2 delims==" %%A in (%PROPERTIES_FILE%) do (
    if "%%A"=="GIT_HASH" set GIT_HASH=%%B
)

if "%GIT_HASH%"=="" (
    echo [ERRO] GIT_HASH nao encontrado em %PROPERTIES_FILE%
    exit /b 1
)

echo ========================================
echo Usando hash: %GIT_HASH%
echo ========================================

REM ========================================
REM 1. REMOVER totaldocs-oauth2-handler DO NODE_MODULES
REM ========================================
echo [INFO] Removendo node_modules/totaldocs-oauth2-handler...
rmdir /s /q "%FRONTEND_DIR%\node_modules\totaldocs-oauth2-handler"

REM ========================================
REM 2. INSTALAR VERSÃO DO REPOSITORIO NO NODE_MODULES
REM ========================================
cd /d "%FRONTEND_DIR%"
echo [INFO] Instalando totaldocs-oauth2-handler com hash %GIT_HASH%...
call npm install git+https://github.com/kevynsantos-sirius/totaldocs-oauth2-handler#%GIT_HASH%

REM ========================================
REM 3. BUILD DO totaldocs-oauth2-handler
REM ========================================
cd node_modules\totaldocs-oauth2-handler
call npm install
call npx tsc
call npm run build
cd /d "%FRONTEND_DIR%"

REM ========================================
REM 4. BUILD DO totaldocs-repository-frontend
REM ========================================
echo [INFO] Rodando npm install e build no frontend principal...
call npm install
call npm run build

REM ========================================
REM 5. COPIAR DIST PARA NGINX
REM ========================================
echo [INFO] Copiando dist para %NGINX_DIR%\frontend\dist\totaldocs-repository-frontend...
xcopy /s /e /y "%FRONTEND_DIR%\dist" "%NGINX_DIR%\frontend\dist\totaldocs-repository-frontend"

REM ========================================
REM 6. REINICIAR CONTAINER DOCKER
REM ========================================
echo [INFO] Removendo container antigo...
docker rm -f nginx-react-struts

echo [INFO] Subindo novo container...
cd /d "%NGINX_DIR%"
docker run --name nginx-react-struts ^
-v "%cd%\frontend\dist:/usr/share/nginx/html" ^
-v "%cd%\nginx.conf:/etc/nginx/nginx.conf" ^
-p 80:80 -d nginx

echo ========================================
echo [SUCESSO] Build e deploy finalizado!
echo ========================================

endlocal
pause
