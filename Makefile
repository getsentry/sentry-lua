.PHONY: build test clean install docs

# Build Teal files to Lua
build:
	mkdir -p build/sentry/{core,utils,platforms}
	tl gen src/sentry/utils/stacktrace.tl -o build/sentry/utils/stacktrace.lua
	tl gen src/sentry/utils/serialize.tl -o build/sentry/utils/serialize.lua
	tl gen src/sentry/utils/dsn.tl -o build/sentry/utils/dsn.lua
	tl gen src/sentry/utils/os.tl -o build/sentry/utils/os.lua
	tl gen src/sentry/utils/runtime.tl -o build/sentry/utils/runtime.lua
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
	tl gen src/sentry/platforms/redis.tl -o build/sentry/platforms/redis.lua
	tl gen src/sentry/platforms/nginx.tl -o build/sentry/platforms/nginx.lua
	tl gen src/sentry/platforms/roblox.tl -o build/sentry/platforms/roblox.lua
	tl gen src/sentry/platforms/love2d.tl -o build/sentry/platforms/love2d.lua
	tl gen src/sentry/platforms/desktop.tl -o build/sentry/platforms/desktop.lua
	tl gen src/sentry/platforms/roblox_file_io.tl -o build/sentry/platforms/roblox_file_io.lua
	tl gen src/sentry/platforms/defold_file_io.tl -o build/sentry/platforms/defold_file_io.lua

# Run unit tests
test: build
	busted

# Clean build artifacts
clean:
	rm -rf build/

# Install dependencies
install:
	luarocks install busted
	luarocks install tl
	luarocks install lua-cjson
	luarocks install luasocket
	luarocks install tealdoc

# Generate documentation
docs: build
	mkdir -p docs
	tealdoc html -o docs --all src/sentry/*.tl src/sentry/core/*.tl src/sentry/utils/*.tl src/sentry/platforms/*.tl

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
	tl check src/sentry/platforms/*.tl

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
	-tl check src/sentry/platforms/*.tl
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