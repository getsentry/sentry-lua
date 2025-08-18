@echo off
setlocal

if "%1"=="install" goto install
if "%1"=="build" goto build
if "%1"=="test" goto test
if "%1"=="clean" goto clean
if "%1"=="docs" goto docs
if "%1"=="lint" goto lint
if "%1"=="lint-soft" goto lint-soft
if "%1"=="docker-test-redis" goto docker-test-redis
if "%1"=="docker-test-nginx" goto docker-test-nginx
if "%1"=="test-all" goto test-all
if "%1"=="serve-docs" goto serve-docs
if "%1"=="help" goto help
if "%1"=="" goto help

echo Unknown command: %1
goto help

:install
echo Installing dependencies...
luarocks install busted
luarocks install tl
luarocks install lua-cjson
luarocks install luasocket
luarocks install tealdoc
echo Dependencies installed successfully!
goto end

:build
echo Building Teal files...
if not exist build mkdir build
if not exist build\sentry mkdir build\sentry
if not exist build\sentry\core mkdir build\sentry\core
if not exist build\sentry\utils mkdir build\sentry\utils
if not exist build\sentry\integrations mkdir build\sentry\integrations
tl gen src\sentry\utils\stacktrace.tl -o build\sentry\utils\stacktrace.lua
tl gen src\sentry\utils\serialize.tl -o build\sentry\utils\serialize.lua
tl gen src\sentry\utils\dsn.tl -o build\sentry\utils\dsn.lua
tl gen src\sentry\core\context.tl -o build\sentry\core\context.lua
tl gen src\sentry\core\transport.tl -o build\sentry\core\transport.lua
tl gen src\sentry\core\test_transport.tl -o build\sentry\core\test_transport.lua
tl gen src\sentry\core\file_io.tl -o build\sentry\core\file_io.lua
tl gen src\sentry\core\file_transport.tl -o build\sentry\core\file_transport.lua
tl gen src\sentry\core\auto_transport.tl -o build\sentry\core\auto_transport.lua
tl gen src\sentry\core\client.tl -o build\sentry\core\client.lua
tl gen src\sentry\init.tl -o build\sentry\init.lua
tl gen src\sentry\integrations\redis.tl -o build\sentry\integrations\redis.lua
tl gen src\sentry\integrations\nginx.tl -o build\sentry\integrations\nginx.lua
tl gen src\sentry\integrations\roblox.tl -o build\sentry\integrations\roblox.lua
tl gen src\sentry\integrations\love2d.tl -o build\sentry\integrations\love2d.lua
tl gen src\sentry\integrations\roblox_file_io.tl -o build\sentry\integrations\roblox_file_io.lua
tl gen src\sentry\integrations\defold_file_io.tl -o build\sentry\integrations\defold_file_io.lua
echo Build completed!
goto end

:test
echo Running unit tests...
call :build
busted
goto end

:clean
echo Cleaning build artifacts...
if exist build rmdir /s /q build
echo Clean completed!
goto end

:docs
echo Generating documentation...
call :build
if not exist docs mkdir docs
tealdoc html -o docs --all src\sentry\init.tl src\sentry\core\context.tl src\sentry\core\transport.tl src\sentry\core\mock_transport.tl src\sentry\core\client.tl src\sentry\utils\stacktrace.tl src\sentry\utils\serialize.tl src\sentry\integrations\redis.tl src\sentry\integrations\nginx.tl src\sentry\integrations\roblox.tl src\sentry\integrations\love2d.tl
echo Documentation generated!
goto end

:lint
echo Linting Teal code...
tl check src\sentry\init.tl
tl check src\sentry\core\context.tl
tl check src\sentry\core\transport.tl
tl check src\sentry\core\test_transport.tl
tl check src\sentry\core\file_io.tl
tl check src\sentry\core\file_transport.tl
tl check src\sentry\core\client.tl
tl check src\sentry\utils\stacktrace.tl
tl check src\sentry\utils\serialize.tl
tl check src\sentry\integrations\redis.tl
tl check src\sentry\integrations\nginx.tl
tl check src\sentry\integrations\roblox.tl
tl check src\sentry\integrations\love2d.tl
echo Linting completed!
goto end

:lint-soft
echo Linting Teal code (permissive)...
tl check src\sentry\init.tl 2>nul
tl check src\sentry\core\context.tl 2>nul
tl check src\sentry\core\transport.tl 2>nul
tl check src\sentry\core\test_transport.tl
tl check src\sentry\core\file_io.tl
tl check src\sentry\core\file_transport.tl 2>nul
tl check src\sentry\core\client.tl 2>nul
tl check src\sentry\utils\stacktrace.tl 2>nul
tl check src\sentry\utils\serialize.tl 2>nul
tl check src\sentry\integrations\redis.tl 2>nul
tl check src\sentry\integrations\nginx.tl 2>nul
tl check src\sentry\integrations\roblox.tl 2>nul
tl check src\sentry\integrations\love2d.tl 2>nul
echo Soft linting completed (warnings ignored)!
goto end

:docker-test-redis
echo Running Redis Docker tests...
docker-compose -f docker/redis/docker-compose.yml up --build --abort-on-container-exit
goto end

:docker-test-nginx
echo Running nginx Docker tests...
docker-compose -f docker/nginx/docker-compose.yml up --build --abort-on-container-exit
goto end

:test-all
echo Running full test suite...
call :test
call :docker-test-redis
call :docker-test-nginx
echo All tests completed!
goto end

:serve-docs
echo Starting documentation server...
call :docs
echo Starting server at http://localhost:8000
echo Press Ctrl+C to stop
python -m http.server 8000 --directory docs
goto end

:help
echo Sentry Lua SDK Build Script
echo.
echo Usage: build.bat [command]
echo.
echo Commands:
echo   install           Install dependencies
echo   build             Build Teal files to Lua
echo   test              Run unit tests
echo   clean             Clean build artifacts
echo   docs              Generate documentation
echo   lint              Lint Teal source code (strict)
echo   lint-soft         Lint Teal source code (permissive)
echo   docker-test-redis Run Redis integration tests
echo   docker-test-nginx Run nginx integration tests
echo   test-all          Run full test suite
echo   serve-docs        Serve documentation locally
echo   help              Show this help
echo.
echo Examples:
echo   build.bat install
echo   build.bat build
echo   build.bat test
goto end

:end