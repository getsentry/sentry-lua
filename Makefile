.PHONY: build test test-coverage coverage-report clean install docs

# Build Teal files to Lua
build:
	rm -rf build/
	find src/sentry -type d | sed 's|src/sentry|build/sentry|' | xargs mkdir -p
	find src/sentry -name "*.tl" -type f | while read -r tl_file; do \
		lua_file=$$(echo "$$tl_file" | sed 's|src/sentry|build/sentry|' | sed 's|\.tl$$|.lua|'); \
		echo "Compiling $$tl_file -> $$lua_file"; \
		tl gen "$$tl_file" -o "$$lua_file" || exit 1; \
	done

# Run unit tests
test: build
	busted

# Run unit tests with coverage
test-coverage: build
	rm -f luacov.*.out test-results.xml
	LUA_PATH="build/?.lua;build/?/init.lua;;" busted --coverage
	luacov
	@# Generate test results in JUnit XML format for codecov test analytics
	LUA_PATH="build/?.lua;build/?/init.lua;;" busted --output=junit > test-results.xml

# Generate coverage report in LCOV format for codecov
coverage-report: test-coverage
	@# Try LCOV format first, fallback to copying luacov report if LCOV fails
	@if ! lua -e "require('luacov.reporter.lcov').report()" > coverage.info 2>/dev/null; then \
		echo "LCOV reporter failed, using luacov report format"; \
		cp luacov.report.out coverage.info; \
	fi
	@# Map build/*.lua file paths to src/*.tl source paths for Codecov
	@sed -i.bak 's|SF:build/sentry/\(.*\)\.lua|SF:src/sentry/\1.tl|g' coverage.info
	@rm -f coverage.info.bak
	@# Verify that mapped source files actually exist
	@echo "Verifying coverage file paths..."
	@grep "^SF:" coverage.info | sed 's/^SF://' | while read -r file; do \
		if [ ! -f "$$file" ]; then \
			echo "Warning: Source file $$file not found in repository"; \
		fi; \
	done
	@echo "Coverage report generated in coverage.info with source mapping"

# Clean build artifacts
clean:
	rm -rf build/
	rm -f luacov.*.out coverage.info test-results.xml

# Install dependencies
install:
	luarocks install busted
	luarocks install tl
	luarocks install lua-cjson
	luarocks install luasocket
	@if [ -n "$$OPENSSL_DIR" ]; then \
		echo "Installing luasec with OPENSSL_DIR=$$OPENSSL_DIR"; \
		luarocks install luasec OPENSSL_DIR=$$OPENSSL_DIR; \
	else \
		luarocks install luasec; \
	fi
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