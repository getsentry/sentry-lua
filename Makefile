.PHONY: build test test-coverage coverage-report clean install docs

# Build Teal files to Lua
build:
	rm -rf build/
	mkdir -p build/sentry/{core,utils,platforms/{standard,roblox,love2d,nginx,redis,defold,test}}
	tl gen src/sentry/utils/stacktrace.tl -o build/sentry/utils/stacktrace.lua
	tl gen src/sentry/utils/serialize.tl -o build/sentry/utils/serialize.lua
	tl gen src/sentry/utils/dsn.tl -o build/sentry/utils/dsn.lua
	tl gen src/sentry/utils/os.tl -o build/sentry/utils/os.lua
	tl gen src/sentry/utils/runtime.tl -o build/sentry/utils/runtime.lua
	tl gen src/sentry/utils/transport.tl -o build/sentry/utils/transport.lua
	tl gen src/sentry/utils/json.tl -o build/sentry/utils/json.lua
	tl gen src/sentry/utils/http.tl -o build/sentry/utils/http.lua
	tl gen src/sentry/core/context.tl -o build/sentry/core/context.lua
	tl gen src/sentry/core/scope.tl -o build/sentry/core/scope.lua
	tl gen src/sentry/core/transport.tl -o build/sentry/core/transport.lua
	tl gen src/sentry/core/test_transport.tl -o build/sentry/core/test_transport.lua
	tl gen src/sentry/core/file_io.tl -o build/sentry/core/file_io.lua
	tl gen src/sentry/core/file_transport.tl -o build/sentry/core/file_transport.lua
	tl gen src/sentry/core/auto_transport.tl -o build/sentry/core/auto_transport.lua
	tl gen src/sentry/core/client.tl -o build/sentry/core/client.lua
	tl gen src/sentry/types.tl -o build/sentry/types.lua
	tl gen src/sentry/platform_loader.tl -o build/sentry/platform_loader.lua
	tl gen src/sentry/init.tl -o build/sentry/init.lua
	# Platform-specific modules
	tl gen src/sentry/platforms/standard/os_detection.tl -o build/sentry/platforms/standard/os_detection.lua
	tl gen src/sentry/platforms/standard/transport.tl -o build/sentry/platforms/standard/transport.lua
	tl gen src/sentry/platforms/standard/file_transport.tl -o build/sentry/platforms/standard/file_transport.lua
	tl gen src/sentry/platforms/roblox/os_detection.tl -o build/sentry/platforms/roblox/os_detection.lua
	tl gen src/sentry/platforms/roblox/transport.tl -o build/sentry/platforms/roblox/transport.lua
	tl gen src/sentry/platforms/roblox/context.tl -o build/sentry/platforms/roblox/context.lua
	tl gen src/sentry/platforms/roblox/file_io.tl -o build/sentry/platforms/roblox/file_io.lua
	tl gen src/sentry/platforms/love2d/os_detection.tl -o build/sentry/platforms/love2d/os_detection.lua
	tl gen src/sentry/platforms/love2d/transport.tl -o build/sentry/platforms/love2d/transport.lua
	tl gen src/sentry/platforms/love2d/context.tl -o build/sentry/platforms/love2d/context.lua
	tl gen src/sentry/platforms/nginx/os_detection.tl -o build/sentry/platforms/nginx/os_detection.lua
	tl gen src/sentry/platforms/nginx/transport.tl -o build/sentry/platforms/nginx/transport.lua
	tl gen src/sentry/platforms/redis/transport.tl -o build/sentry/platforms/redis/transport.lua
	tl gen src/sentry/platforms/defold/transport.tl -o build/sentry/platforms/defold/transport.lua
	tl gen src/sentry/platforms/defold/file_io.tl -o build/sentry/platforms/defold/file_io.lua
	tl gen src/sentry/platforms/test/transport.tl -o build/sentry/platforms/test/transport.lua

# Run unit tests
test: build
	busted

# Run unit tests with coverage
test-coverage: build
	rm -f luacov.*.out
	LUA_PATH="build/?.lua;build/?/init.lua;;" busted --coverage
	luacov

# Generate coverage report in LCOV format for codecov
coverage-report: test-coverage
	cp luacov.report.out coverage.info
	@echo "Coverage report generated in coverage.info"

# Clean build artifacts
clean:
	rm -rf build/
	rm -f luacov.*.out coverage.info

# Install dependencies
install:
	luarocks install busted
	luarocks install tl
	luarocks install lua-cjson
	luarocks install luasocket
	luarocks install luacov
	luarocks install luacov-reporter-lcov

# Install all dependencies including docs tools
install-all: install
	luarocks install tealdoc

# Generate documentation
docs: build install-all
	mkdir -p docs
	tealdoc html -o docs --all src/sentry/*.tl src/sentry/core/*.tl src/sentry/utils/*.tl src/sentry/platforms/**/*.tl

# Lint code (strict)
lint:
	tl check src/sentry/init.tl
	tl check src/sentry/core/context.tl
	tl check src/sentry/core/transport.tl
	tl check src/sentry/core/test_transport.tl
	tl check src/sentry/core/file_io.tl
	tl check src/sentry/core/file_transport.tl
	tl check src/sentry/core/client.tl
	tl check src/sentry/utils/*.tl
	tl check src/sentry/platforms/**/*.tl

# Lint code (permissive - ignore external module warnings)
lint-soft:
	-tl check src/sentry/init.tl
	-tl check src/sentry/core/context.tl
	-tl check src/sentry/core/transport.tl
	-tl check src/sentry/core/test_transport.tl
	-tl check src/sentry/core/file_io.tl
	-tl check src/sentry/core/file_transport.tl
	-tl check src/sentry/core/client.tl
	-tl check src/sentry/utils/*.tl
	-tl check src/sentry/platforms/**/*.tl
	@echo "Soft lint completed (warnings ignored)"

# Docker tests
docker-test-redis:
	docker-compose -f docker/redis/docker-compose.yml up --build --abort-on-container-exit

docker-test-nginx:
	docker-compose -f docker/nginx/docker-compose.yml up --build --abort-on-container-exit

# Full test suite
test-all: test docker-test-redis docker-test-nginx

# Serve documentation locally
serve-docs: docs
	@echo "Starting documentation server at http://localhost:8000"
	@echo "Press Ctrl+C to stop"
	python3 -m http.server 8000 --directory docs