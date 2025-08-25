#!/usr/bin/env pwsh
#
# Windows Development Environment Setup
# Sets up Lua + LuaRocks + dependencies from source for Windows development
#

param(
    [string]$LuaVersion = "5.4",
    [string]$RootPath = "build"
)

$ErrorActionPreference = "Stop"

Write-Host "Setting up Windows development environment"
Write-Host "Lua version: $LuaVersion"
Write-Host "Installation root: $RootPath (relative to repository)"
Write-Host ""

# Ensure we're in the repository root
$RepoRoot = Split-Path -Parent $PSScriptRoot
Push-Location $RepoRoot
$RootPath = Join-Path $PWD $RootPath

$LuaInstallPath = "$RootPath\lua-$LuaVersion"
$LuaRocksInstallPath = "$RootPath\luarocks"

# Step 1: Build Lua from source
Write-Host "Step 1: Building Lua $LuaVersion from source..."
& "$PSScriptRoot\build-lua-windows.ps1" -LuaVersion $LuaVersion -InstallPath $LuaInstallPath

if ($LASTEXITCODE -ne 0) {
    throw "Lua build failed"
}

# Step 2: Build LuaRocks from source  
Write-Host "Step 2: Building LuaRocks from source..."
& "$PSScriptRoot\build-luarocks-windows.ps1" -LuaPath $LuaInstallPath -InstallPath $LuaRocksInstallPath

if ($LASTEXITCODE -ne 0) {
    throw "LuaRocks build failed"
}

# Step 3: Add to PATH for current session
Write-Host "Step 3: Setting up environment..."
$env:PATH = "$LuaInstallPath\bin;$LuaRocksInstallPath;" + $env:PATH

# Verify installation
Write-Host "Step 4: Verifying installation..."
Write-Host "Testing Lua..."
$luaOutput = & lua -e "print('Lua is working: ' .. _VERSION)"
Write-Host $luaOutput

Write-Host "Testing LuaRocks..."
$luarocksOutput = & luarocks --version 2>&1 | Select-Object -First 1
Write-Host $luarocksOutput

# Step 5: Install development dependencies
Write-Host "Step 5: Installing development dependencies..."

$dependencies = @(
    "busted",
    "lua-cjson", 
    "luasocket",
    "luasec",
    "luacov",
    "luacov-reporter-lcov",
    "luacheck"
)

foreach ($dep in $dependencies) {
    Write-Host "Installing $dep..."
    & luarocks install $dep
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Warning: Failed to install $dep (may need compiler for native components)"
    } else {
        Write-Host "SUCCESS: $dep installed successfully"
    }
}

Write-Host ""
Write-Host "Windows development environment setup complete!"
Write-Host ""
Pop-Location

Write-Host "To use this environment:"
Write-Host "  Add to your PATH: $LuaInstallPath\bin;$LuaRocksInstallPath"
Write-Host "  Or run from repository root:"
Write-Host "  `$env:PATH = `"$LuaInstallPath\bin;$LuaRocksInstallPath;`" + `$env:PATH"
Write-Host ""
Write-Host "Test the setup:"
Write-Host "  lua scripts/dev.lua test"

exit 0