#!/usr/bin/env lua

local function run_command(cmd, description)
  if description then print("🔧 " .. description) end
  print("$ " .. cmd)
  local result = os.execute(cmd)
  if result ~= 0 and result ~= true then
    print("❌ Command failed: " .. cmd)
    os.exit(1)
  end
  print("✅ Success")
  print("")
  return result
end

local function file_exists(path)
  local file = io.open(path, "r")
  if file then
    file:close()
    return true
  end
  return false
end

local function get_luarocks_path()
  -- Try to detect luarocks installation
  local handle = io.popen("luarocks path 2>/dev/null || echo ''")
  local result = handle:read("*a")
  handle:close()
  return result and result ~= ""
end

local function install_dependencies()
  print("📦 Installing dependencies...")

  if not get_luarocks_path() then
    print("❌ LuaRocks not found. Please install LuaRocks first.")
    os.exit(1)
  end

  -- Install test dependencies
  run_command("luarocks install busted", "Installing busted test framework")
  run_command("luarocks install lua-cjson", "Installing JSON support")
  run_command("luarocks install luasocket", "Installing socket support")
  
  -- Install luasec with OpenSSL directory if available
  local openssl_dir = os.getenv("OPENSSL_DIR")
  if openssl_dir then
    run_command("luarocks install luasec OPENSSL_DIR=" .. openssl_dir, "Installing SSL/HTTPS support")
  else
    run_command("luarocks install luasec", "Installing SSL/HTTPS support")
  end
  
  run_command("luarocks install luacov", "Installing coverage tool")
  run_command("luarocks install luacov-reporter-lcov", "Installing LCOV reporter")

  -- Install development dependencies
  run_command("luarocks install luacheck", "Installing luacheck linter")
end

local function run_tests()
  print("🧪 Running tests...")

  if not file_exists("spec") then
    print("❌ No spec directory found")
    os.exit(1)
  end

  -- Run busted tests
  run_command("busted", "Running test suite")
end

local function run_coverage()
  print("📊 Running tests with coverage...")

  -- Run tests with coverage
  run_command("busted --coverage", "Running tests with coverage")

  -- Generate coverage reports
  if file_exists("luacov.stats.out") then
    run_command("luacov", "Generating coverage report")
    if file_exists("luacov.report.out") then 
      print("✅ Coverage report generated: luacov.report.out") 
    end
  else
    print("⚠️  No coverage stats found. Make sure busted --coverage ran successfully.")
  end
end

local function run_lint()
  print("🔍 Running linter...")

  -- Try to find luacheck in common locations
  local luacheck_paths = {
    "luacheck",
    "~/.luarocks/bin/luacheck",
    "/usr/local/bin/luacheck",
    os.getenv("HOME") .. "/.luarocks/bin/luacheck",
  }

  local luacheck_cmd = nil
  for _, path in ipairs(luacheck_paths) do
    local expanded_path = path:gsub("~", os.getenv("HOME") or "~")
    local test_result = os.execute(expanded_path .. " --version 2>/dev/null")
    if test_result == 0 or test_result == true then
      luacheck_cmd = expanded_path
      break
    end
  end

  if not luacheck_cmd then
    print("❌ luacheck not found. Install with: luarocks install luacheck")
    print("   Or ensure luacheck is in your PATH")
    os.exit(1)
  end

  -- Run luacheck
  run_command(luacheck_cmd .. " .", "Running luacheck")
end

local function run_format_check()
  print("✨ Checking code formatting...")

  -- Check if stylua is available
  local handle = io.popen("stylua --version 2>/dev/null")
  local stylua_version = handle:read("*l")
  handle:close()

  if not stylua_version then
    print("⚠️  StyLua not found. Install with: cargo install stylua")
    return
  end

  -- Check formatting
  local result = os.execute("stylua --check .")
  if result ~= 0 and result ~= true then
    print("❌ Code formatting issues found. Run: lua scripts/dev.lua format")
    os.exit(1)
  else
    print("✅ Code formatting is correct")
  end
end

local function run_format()
  print("✨ Formatting code...")

  -- Check if stylua is available
  local handle = io.popen("stylua --version 2>/dev/null")
  local stylua_version = handle:read("*l")
  handle:close()

  if not stylua_version then
    print("❌ StyLua not found. Install with: cargo install stylua")
    os.exit(1)
  end

  -- Format code
  run_command("stylua .", "Formatting Lua code")
end

local function test_love2d()
  print("TODO")
  
end

local function test_rockspec()
  print("📋 Testing rockspec installation...")

  -- Find rockspec file
  local handle = io.popen("ls *.rockspec 2>/dev/null || dir *.rockspec 2>nul")
  local rockspec = handle:read("*l")
  handle:close()

  if not rockspec then
    print("❌ No rockspec file found")
    os.exit(1)
  end

  -- Test installation
  run_command("luarocks make " .. rockspec, "Testing rockspec installation")
end

local function clean()
  print("🧹 Cleaning build artifacts...")

  -- Clean coverage files
  if file_exists("luacov.stats.out") then run_command("rm luacov.stats.out", "Removing coverage stats") end
  if file_exists("luacov.report.out") then run_command("rm luacov.report.out", "Removing coverage report") end
  if file_exists("coverage.info") then run_command("rm coverage.info", "Removing LCOV report") end
  if file_exists("test-results.xml") then run_command("rm test-results.xml", "Removing test results") end
end

local function show_help()
  print("🚀 Sentry Lua SDK Development Script")
  print("")
  print("Usage: lua scripts/dev.lua [command]")
  print("")
  print("Commands:")
  print("  install      Install dependencies")
  print("  test         Run tests")
  print("  coverage     Run tests with coverage")
  print("  lint         Run linter (luacheck)")
  print("  format-check Check code formatting")
  print("  format       Format code with StyLua")
  print("  test-rockspec Test rockspec installation")
  print("  ci-love2d    Run Love2D integration tests")
  print("  clean        Clean artifacts")
  print("  ci           Run full CI pipeline (lint, format-check, test, coverage)")
  print("  help         Show this help")
  print("")
  print("Examples:")
  print("  lua scripts/dev.lua install")
  print("  lua scripts/dev.lua test")
  print("  lua scripts/dev.lua ci-love2d")
  print("  lua scripts/dev.lua ci")
end

local function run_ci()
  print("🚀 Running full CI pipeline...")
  run_lint()
  run_format_check()
  run_tests()
  run_coverage()
  print("🎉 CI pipeline completed successfully!")
end

-- Main execution
local command = arg and arg[1] or "help"

if command == "install" then
  install_dependencies()
elseif command == "test" then
  run_tests()
elseif command == "coverage" then
  run_coverage()
elseif command == "lint" then
  run_lint()
elseif command == "format-check" then
  run_format_check()
elseif command == "format" then
  run_format()
elseif command == "test-rockspec" then
  test_rockspec()
elseif command == "ci-love2d" then
  test_love2d()
elseif command == "clean" then
  clean()
elseif command == "ci" then
  run_ci()
elseif command == "help" then
  show_help()
else
  print("❌ Unknown command: " .. command)
  print("")
  show_help()
  os.exit(1)
end
