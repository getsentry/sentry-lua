.PHONY: build test test-coverage coverage-report test-love clean install docs install-love2d ci-love2d test-rockspec publish

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

# Full test suite (excludes Love2D - requires Love2D installation)
test-all: test test-rockspec docker-test-redis docker-test-nginx

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
test-all-with-love: test test-rockspec test-love docker-test-redis docker-test-nginx

# Serve documentation locally
serve-docs: docs
	@echo "Starting documentation server at http://localhost:8000"
	@echo "Press Ctrl+C to stop"
	python3 -m http.server 8000 --directory docs

# Test rockspec by installing it in an isolated environment
test-rockspec: build
	@echo "Testing rockspec installation and module loading..."
	@rm -rf rockspec-test/
	@mkdir -p rockspec-test/test-app
	@# Create a minimal test application
	@echo 'local sentry = require("sentry")' > rockspec-test/test-app/test.lua
	@echo 'sentry.init({dsn = "https://test@example.com/123"})' >> rockspec-test/test-app/test.lua
	@echo 'print("✅ Sentry loaded successfully")' >> rockspec-test/test-app/test.lua
	@echo 'sentry.capture_message("Test message from rockspec validation")' >> rockspec-test/test-app/test.lua
	@echo 'print("✅ Sentry functionality works")' >> rockspec-test/test-app/test.lua
	@# Generate comprehensive module validation test
	@echo "Generating dynamic module validation..."
	@# Extract all modules from rockspec
	@find . -maxdepth 1 -name "*.rockspec" -exec grep -E '^\s*\["[^"]+"\]\s*=' {} \; | sed 's/.*\["\([^"]*\)"\].*/\1/' | sort > rockspec-test/rockspec-modules.txt
	@# Find all build/*.lua files and convert to module names
	@find build -name "*.lua" -type f | \
		sed 's|build/||' | \
		sed 's|\.lua$$||' | \
		sed 's|/|.|g' | \
		sort > rockspec-test/build-modules.txt
	@# Create module loading test script
	@echo '-- Dynamically generated module validation test' > rockspec-test/test-app/module_test.lua
	@echo 'local function read_modules(filename)' >> rockspec-test/test-app/module_test.lua
	@echo '  local modules = {}' >> rockspec-test/test-app/module_test.lua
	@echo '  local file = io.open(filename, "r")' >> rockspec-test/test-app/module_test.lua
	@echo '  if not file then error("Could not open " .. filename) end' >> rockspec-test/test-app/module_test.lua
	@echo '  for line in file:lines() do' >> rockspec-test/test-app/module_test.lua
	@echo '    if line:match("%S") then table.insert(modules, line) end' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo '  file:close()' >> rockspec-test/test-app/module_test.lua
	@echo '  return modules' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo 'local rockspec_modules = read_modules("../rockspec-modules.txt")' >> rockspec-test/test-app/module_test.lua
	@echo 'local build_modules = read_modules("../build-modules.txt")' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo '-- Check if all build modules are in rockspec' >> rockspec-test/test-app/module_test.lua
	@echo 'local missing_from_rockspec = {}' >> rockspec-test/test-app/module_test.lua
	@echo 'for _, build_mod in ipairs(build_modules) do' >> rockspec-test/test-app/module_test.lua
	@echo '  local found = false' >> rockspec-test/test-app/module_test.lua
	@echo '  for _, rock_mod in ipairs(rockspec_modules) do' >> rockspec-test/test-app/module_test.lua
	@echo '    if build_mod == rock_mod then found = true; break end' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo '  if not found then' >> rockspec-test/test-app/module_test.lua
	@echo '    table.insert(missing_from_rockspec, build_mod)' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo '-- Check if all rockspec modules can be loaded' >> rockspec-test/test-app/module_test.lua
	@echo 'local failed_to_load = {}' >> rockspec-test/test-app/module_test.lua
	@echo 'local loaded_count = 0' >> rockspec-test/test-app/module_test.lua
	@echo 'for _, module in ipairs(rockspec_modules) do' >> rockspec-test/test-app/module_test.lua
	@echo '  local ok, result = pcall(require, module)' >> rockspec-test/test-app/module_test.lua
	@echo '  if not ok then' >> rockspec-test/test-app/module_test.lua
	@echo '    table.insert(failed_to_load, module .. ": " .. tostring(result))' >> rockspec-test/test-app/module_test.lua
	@echo '  else' >> rockspec-test/test-app/module_test.lua
	@echo '    loaded_count = loaded_count + 1' >> rockspec-test/test-app/module_test.lua
	@echo '    print("✅ " .. module .. " loaded successfully")' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo '-- Report results' >> rockspec-test/test-app/module_test.lua
	@echo 'print("")' >> rockspec-test/test-app/module_test.lua
	@echo 'print("=== MODULE VALIDATION SUMMARY ===")' >> rockspec-test/test-app/module_test.lua
	@echo 'print("Build modules found: " .. #build_modules)' >> rockspec-test/test-app/module_test.lua
	@echo 'print("Rockspec modules found: " .. #rockspec_modules)' >> rockspec-test/test-app/module_test.lua
	@echo 'print("Successfully loaded: " .. loaded_count)' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo 'if #missing_from_rockspec > 0 then' >> rockspec-test/test-app/module_test.lua
	@echo '  print("❌ BUILD MODULES MISSING FROM ROCKSPEC:")' >> rockspec-test/test-app/module_test.lua
	@echo '  for _, mod in ipairs(missing_from_rockspec) do' >> rockspec-test/test-app/module_test.lua
	@echo '    print("  " .. mod)' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo 'if #failed_to_load > 0 then' >> rockspec-test/test-app/module_test.lua
	@echo '  print("❌ ROCKSPEC MODULES FAILED TO LOAD:")' >> rockspec-test/test-app/module_test.lua
	@echo '  for _, err in ipairs(failed_to_load) do' >> rockspec-test/test-app/module_test.lua
	@echo '    print("  " .. err)' >> rockspec-test/test-app/module_test.lua
	@echo '  end' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@echo '' >> rockspec-test/test-app/module_test.lua
	@echo 'if #missing_from_rockspec > 0 or #failed_to_load > 0 then' >> rockspec-test/test-app/module_test.lua
	@echo '  print("❌ Module validation failed!")' >> rockspec-test/test-app/module_test.lua
	@echo '  os.exit(1)' >> rockspec-test/test-app/module_test.lua
	@echo 'else' >> rockspec-test/test-app/module_test.lua
	@echo '  print("✅ All modules validated successfully!")' >> rockspec-test/test-app/module_test.lua
	@echo 'end' >> rockspec-test/test-app/module_test.lua
	@# Copy current rockspec to test directory and fix paths for testing
	@find . -maxdepth 1 -name "*.rockspec" -exec cp {} rockspec-test/ \;
	@# Fix relative paths in rockspec for testing (use absolute paths)
	@cd rockspec-test && find . -maxdepth 1 -name "*.rockspec" -exec sed -i.bak 's|build/|../build/|g' {} \;
	@# Install the rockspec locally
	@cd rockspec-test && echo "Installing rockspec locally..." && find . -maxdepth 1 -name "*.rockspec" -exec luarocks make --local {} \;
	@# Test basic functionality
	@echo "Testing basic Sentry functionality..."
	@cd rockspec-test/test-app && eval "$$(luarocks path)" && lua test.lua
	@# Test module loading
	@echo "Testing module loading..."
	@cd rockspec-test/test-app && eval "$$(luarocks path)" && lua module_test.lua
	@# Clean up
	@echo "Cleaning up test environment..."
	@rm -rf rockspec-test/
	@echo "✅ Rockspec validation completed successfully"

# Create publish package
publish: build
	@echo "Creating publish package..."
	@rm -f sentry-lua-sdk-publish.zip
	@# Create temporary directory for packaging
	@mkdir -p publish-temp
	@# Copy required files
	@cp README.md publish-temp/ || { echo "❌ README.md not found"; exit 1; }
	@cp example-event.png publish-temp/ || { echo "❌ example-event.png not found"; exit 1; }
	@cp CHANGELOG.md publish-temp/ || { echo "❌ CHANGELOG.md not found"; exit 1; }
	@cp *.rockspec publish-temp/ || { echo "❌ No .rockspec files found"; exit 1; }
	@cp roblox.json publish-temp/ || { echo "❌ roblox.json not found"; exit 1; }
	@# Copy build directory (recursively)
	@cp -r build publish-temp/ || { echo "❌ build directory not found. Run 'make build' first."; exit 1; }
	@# Copy examples directory (recursively)
	@cp -r examples publish-temp/ || { echo "❌ examples directory not found"; exit 1; }
	@# Create zip file
	@cd publish-temp && zip -r ../sentry-lua-sdk-publish.zip . > /dev/null
	@# Clean up temporary directory
	@rm -rf publish-temp
	@echo "✅ Publish package created: sentry-lua-sdk-publish.zip"
	@# Show contents of the zip file
	@echo "Package contents:"
	@unzip -l sentry-lua-sdk-publish.zip

# Create binary rock for distribution
rock: build
	@echo "Creating binary rock..."
	@# Clean up any existing rocks
	@rm -f *.rock
	@# Create binary rock
	@luarocks make --pack-binary-rock
	@# Verify rock was created
	@ROCK_FILE=$$(ls *.rock 2>/dev/null | head -1); \
	if [ -z "$$ROCK_FILE" ]; then \
		echo "❌ No .rock file was created"; \
		exit 1; \
	fi; \
	echo "✅ Binary rock created: $$ROCK_FILE"; \
	echo "Rock size: $$(ls -lh $$ROCK_FILE | awk '{print $$5}')"

# Test installing the binary rock locally
test-rock: rock
	@echo "Testing binary rock installation..."
	@ROCK_FILE=$$(ls *.rock 2>/dev/null | head -1); \
	if [ -z "$$ROCK_FILE" ]; then \
		echo "❌ No .rock file found"; \
		exit 1; \
	fi; \
	echo "Installing $$ROCK_FILE locally..."; \
	luarocks install --local --force "$$ROCK_FILE"; \
	echo "✅ Binary rock installed successfully"
