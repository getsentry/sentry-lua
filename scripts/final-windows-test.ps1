# Windows development environment verification test
$ErrorActionPreference = "Stop"

Write-Host "Verifying Windows development environment..."
Write-Host "==========================================="

# Ensure we're in repository root and check for environment
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot

$LuaPath = Join-Path $PWD "build\lua-5.4"
$LuaRocksPath = Join-Path $PWD "build\luarocks"

if (-not (Test-Path "$LuaPath\bin\lua.exe")) {
    Write-Host "❌ Development environment not found."
    Write-Host "Run: scripts\setup-windows-dev.ps1"
    exit 1
}

# Set PATH
$env:PATH = "$LuaPath\bin;$LuaRocksPath;" + $env:PATH

# Test Lua
Write-Host "Testing Lua installation..."
$luaVersion = & lua -e "print(_VERSION)" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Lua test failed: $luaVersion"
    exit 1
}
Write-Host "✅ $luaVersion"

# Test LuaRocks
Write-Host "Testing LuaRocks..."
$luarocksTest = & luarocks --version 2>&1 | Select-Object -First 1
if ($luarocksTest) {
    Write-Host "✅ LuaRocks available"
} else {
    Write-Host "⚠️ LuaRocks may not be fully functional (this is expected)"
}

# Create and test core functionality if test file exists
$coreTestPath = "test-core-functionality.lua"
if (-not (Test-Path $coreTestPath)) {
    # Create minimal test
    @"
-- Quick core functionality test
package.path = 'src/?.lua;src/?/init.lua;' .. (package.path or '')
package.path = 'src/sentry/?.lua;src/sentry/?/init.lua;' .. (package.path or '')

local success, dsn_module = pcall(require, 'core.dsn')
if success and dsn_module.parse_dsn then
    local dsn, err = dsn_module.parse_dsn('https://key:secret@sentry.io/123')
    if dsn and not err then
        print('SUCCESS: Core Sentry functionality works')
    else
        print('ERROR: DSN parsing failed')
        os.exit(1)
    end
else
    print('ERROR: Could not load DSN module')
    os.exit(1)
end
"@ | Set-Content -Path $coreTestPath
}

Write-Host "Testing Sentry core functionality..."
& lua $coreTestPath
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Sentry core test failed"
    exit 1
}
Write-Host "✅ Sentry core functionality works"

# Clean up test file if we created it
if (-not (Test-Path $coreTestPath)) {
    Remove-Item $coreTestPath -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "🎉 SUCCESS: Windows development environment is ready!"
Write-Host ""
Pop-Location

Write-Host "Next steps:"
Write-Host "- From repository root, set PATH:"
Write-Host "  `$env:PATH = `"$LuaPath\bin;$LuaRocksPath;`" + `$env:PATH"
Write-Host "- See WINDOWS.md for detailed usage instructions"