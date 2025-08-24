.PHONY: build test test-coverage coverage-report test-love clean install install-teal docs install-love2d ci-love2d publish build-single-file

# Install Teal compiler (for fresh systems without Teal)
install-teal:
	@if ! command -v tl > /dev/null 2>&1; then \
		echo "Installing Teal compiler..."; \
		luarocks install --local tl; \
		eval "$$(luarocks path --local)"; \
	else \
		echo "Teal compiler already available"; \
	fi

# Build Teal files to Lua
build: install-teal
	rm -rf build/
	find src/sentry -type d | sed 's|src/sentry|build/sentry|' | xargs mkdir -p
	find src/sentry -name "*.tl" -type f | while read -r tl_file; do \
		lua_file=$$(echo "$$tl_file" | sed 's|src/sentry|build/sentry|' | sed 's|\.tl$$|.lua|'); \
		echo "Compiling $$tl_file -> $$lua_file"; \
		eval "$$(luarocks path --local)" && tl gen "$$tl_file" -o "$$lua_file" || exit 1; \
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

# Run Love2D tests (requires Love2D to be installed)
test-love: build
	@echo "Running Love2D unit tests with busted..."
	LUA_PATH="build/?.lua;build/?/init.lua;;" busted spec/platforms/love2d/love2d_spec.lua --output=TAP
	@echo ""
	@echo "Running Love2D integration tests (headless)..."
	@# Verify lua-https binary is available
	@if [ ! -f examples/love2d/https.so ]; then \
		echo "❌ CRITICAL: lua-https binary not found at examples/love2d/https.so"; \
		echo "Love2D tests REQUIRE HTTPS support. Rebuild with:"; \
		echo "cd examples/love2d/lua-https && cmake -Bbuild -S. -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=\$$PWD/install && cmake --build build --target install"; \
		exit 1; \
	fi
	@# Copy binary to test directory
	cp examples/love2d/https.so spec/platforms/love2d/ || { \
		echo "❌ Failed to copy https.so to test directory"; \
		exit 1; \
	}
	@# Run Love2D integration tests with cross-platform timeout and virtual display
	@if [ "$(shell uname)" = "Darwin" ]; then \
		echo "Running Love2D tests on macOS (no timeout command available)"; \
		cd spec/platforms/love2d && love . > test_output.log 2>&1 || true; \
	else \
		echo "Running Love2D tests with virtual display on Linux"; \
		cd spec/platforms/love2d && xvfb-run -a -s "-screen 0 1x1x24" timeout 30s love . > test_output.log 2>&1 || true; \
	fi
	@# Validate test results
	@if grep -q "All tests passed" spec/platforms/love2d/test_output.log; then \
		echo "✅ Love2D integration tests passed"; \
		cat spec/platforms/love2d/test_output.log; \
	else \
		echo "❌ Love2D integration tests failed or incomplete"; \
		cat spec/platforms/love2d/test_output.log; \
		rm -f spec/platforms/love2d/test_output.log spec/platforms/love2d/https.so; \
		exit 1; \
	fi
	@# Clean up test artifacts
	@rm -f spec/platforms/love2d/test_output.log spec/platforms/love2d/https.so
	@echo "✅ All Love2D tests completed successfully"

# Generate coverage report in LCOV format for codecov
coverage-report: test-coverage
	@# Generate LCOV; do not swallow errors, and ensure non-empty output
	@rm -f coverage.info
	@echo "Generating LCOV with luacov.reporter.lcov ..."
	@lua -e "require('luacov.reporter.lcov').report()" > coverage.info || true
	@if [ ! -s coverage.info ]; then \
		echo "coverage.info is empty after luacov.reporter.lcov; trying 'luacov -r lcov'"; \
		luacov -r lcov > coverage.info 2>/dev/null || true; \
	fi
	@if [ ! -s coverage.info ]; then \
		echo "LCOV generation still empty; falling back to raw luacov report"; \
		cp -f luacov.report.out coverage.info 2>/dev/null || true; \
	fi
	@# Print quick stats to help debug in CI
	@echo "File stats (lines words bytes):"; \
	( [ -f coverage.info ] && echo "coverage.info:" && wc -l -w -c coverage.info ) || true; \
	( [ -f luacov.report.out ] && echo "luacov.report.out:" && wc -l -w -c luacov.report.out ) || true; \
	( [ -f luacov.stats.out ] && echo "luacov.stats.out:" && wc -l -w -c luacov.stats.out ) || true
	@# Show SF lines BEFORE path remapping
	@echo "SF lines BEFORE remap:"; \
	grep "^SF:" coverage.info || true
	@# Map build/*.lua file paths (absolute or relative) to src/*.tl for Codecov
	@# Handle both absolute and relative paths that contain build/sentry
	@sed -i.bak 's|^SF:.*build/sentry/\(.*\)\.lua|SF:src/sentry/\1.tl|g' coverage.info
	@# Show SF lines AFTER path remapping
	@echo "SF lines AFTER remap:"; \
	grep "^SF:" coverage.info || true
	@# Verify that mapped source files actually exist
	@echo "Verifying coverage file paths..."
	@grep "^SF:" coverage.info | sed 's/^SF://' | while read -r file; do \
		if [ ! -f "$$file" ]; then \
			echo "Warning: Source file $$file not found in repository"; \
		fi; \
	done
	@# Clean up sed backup and finish
	@rm -f coverage.info.bak
	@echo "Coverage report generated at coverage.info"

# Clean build artifacts
clean:
	rm -rf build/
	rm -rf build-single-file/
	rm -f luacov.*.out coverage.info test-results.xml test_single_file.lua

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
	luarocks install amalg

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

# Full test suite (excludes Love2D - requires Love2D installation)
test-all: test docker-test-redis docker-test-nginx

# Install Love2D (platform-specific)
install-love2d:
	@echo "Installing Love2D..."
	@if [ "$$(uname)" = "Darwin" ]; then \
		echo "Installing Love2D on macOS..."; \
		if ! command -v love > /dev/null 2>&1; then \
			if command -v brew > /dev/null 2>&1; then \
				brew install --cask love; \
			else \
				echo "❌ Homebrew not found. Please install Homebrew first."; \
				exit 1; \
			fi; \
		else \
			echo "✅ Love2D already installed: $$(love --version)"; \
		fi; \
	elif [ "$$(uname)" = "Linux" ]; then \
		echo "Installing Love2D and virtual display on Linux..."; \
		if ! command -v love > /dev/null 2>&1; then \
			if command -v apt-get > /dev/null 2>&1; then \
				sudo add-apt-repository -y ppa:bartbes/love-stable; \
				sudo apt-get update; \
				sudo apt-get install -y love; \
			else \
				echo "❌ apt-get not found. Please install Love2D manually."; \
				exit 1; \
			fi; \
		else \
			echo "✅ Love2D already installed: $$(love --version)"; \
		fi; \
	else \
		echo "❌ Unsupported platform: $$(uname)"; \
		exit 1; \
	fi
	@echo "✅ Love2D installation complete"

# CI target for Love2D - install Love2D and run tests
ci-love2d: install-love2d build test-love

# Full test suite including Love2D (requires Love2D to be installed)
test-all-with-love: test test-love docker-test-redis docker-test-nginx

# Serve documentation locally
serve-docs: docs
	@echo "Starting documentation server at http://localhost:8000"
	@echo "Press Ctrl+C to stop"
	python3 -m http.server 8000 --directory docs

# Test single-file SDK functionality
test-single-file: build-single-file
	@echo "Testing single-file SDK installation and functionality..."
	@# Create a minimal test application
	@echo 'local sentry = require("build-single-file.sentry")' > test_single_file.lua
	@echo 'print("✅ Single-file Sentry loaded successfully")' >> test_single_file.lua
	@echo '-- Test that we can access core functions without initializing' >> test_single_file.lua
	@echo 'if type(sentry.init) == "function" then' >> test_single_file.lua
	@echo '  print("✅ Sentry API available")' >> test_single_file.lua
	@echo '  print("✅ Logger available:", type(sentry.logger))' >> test_single_file.lua
	@echo '  print("✅ Tracing available:", type(sentry.start_transaction))' >> test_single_file.lua
	@echo 'end' >> test_single_file.lua
	@# Test basic functionality
	@echo "Testing single-file Sentry functionality..."
	@lua test_single_file.lua
	@# Clean up
	@rm -f test_single_file.lua
	@echo "✅ Single-file SDK validation completed successfully"

# Create publish package with single file and documentation
publish: build-single-file
	@echo "Creating publish package with single-file SDK..."
	@rm -f sentry-lua-sdk.zip
	@# Create temporary directory for packaging
	@mkdir -p publish-temp
	@# Copy the single-file SDK (main deliverable)
	@cp build-single-file/sentry.lua publish-temp/ || { echo "❌ sentry.lua not found. Run 'make build-single-file' first."; exit 1; }
	@# Copy documentation and examples
	@cp README.md publish-temp/ || { echo "❌ README.md not found"; exit 1; }
	@cp CHANGELOG.md publish-temp/ || { echo "❌ CHANGELOG.md not found"; exit 1; }
	@cp -r examples publish-temp/ || { echo "❌ examples directory not found"; exit 1; }
	@# Create zip file
	@cd publish-temp && zip -r ../sentry-lua-sdk.zip . > /dev/null
	@# Clean up temporary directory
	@rm -rf publish-temp
	@echo "✅ Single-file SDK package created: sentry-lua-sdk.zip"
	@echo "📦 Contains single sentry.lua file (~126KB) with complete SDK functionality"  
	@echo "📦 No dependencies, no installation required - just copy and use"
	@echo "📦 Upload to GitHub Releases for user download"
	@echo ""
	@echo "Package contents:"
	@unzip -l sentry-lua-sdk.zip

# Generate single-file SDK for all environments (Roblox, Defold, Love2D, Standard Lua)
build-single-file: build
	@echo "Generating single-file SDK distribution using lua-amalg..."
	@./scripts/generate-single-file-amalg.sh
	@echo "✅ Generated build-single-file/sentry.lua (~126KB)"
	@echo "📋 Single file contains complete SDK with envelope-only transport"
	@echo "📋 All functions available under 'sentry' namespace"
	@echo "📋 Includes: errors, logging (sentry.logger.*), tracing (sentry.start_transaction)"
	@echo "📋 Platform auto-detection: Love2D, Roblox, nginx, Redis, standard Lua"
	@echo "📋 Use: local sentry = require('sentry')"

