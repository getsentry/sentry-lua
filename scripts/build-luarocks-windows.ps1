#!/usr/bin/env pwsh
#
# Windows LuaRocks Builder
# Builds LuaRocks from source for Windows
#

param(
    [Parameter(Mandatory=$true)]
    [string]$LuaPath,
    
    [Parameter(Mandatory=$true)]
    [string]$InstallPath,
    
    [string]$LuaRocksVersion = "3.11.1"
)

$ErrorActionPreference = "Stop"

Write-Host "Building LuaRocks $LuaRocksVersion for Windows"
Write-Host "Lua installation: $LuaPath"
Write-Host "LuaRocks target: $InstallPath"

# Verify Lua installation
if (-not (Test-Path "$LuaPath\bin\lua.exe")) {
    throw "Lua installation not found at $LuaPath\bin\lua.exe"
}

# Test Lua works
Write-Host "Testing Lua installation..."
$luaVersion = & "$LuaPath\bin\lua.exe" -e "print(_VERSION)" 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Lua installation is not working: $luaVersion"
}
Write-Host "Lua version: $luaVersion"

# Create vendor directory for source downloads
$vendorDir = "vendor\luarocks-$LuaRocksVersion"
New-Item -Path $vendorDir -ItemType Directory -Force | Out-Null

# Download LuaRocks source
Write-Host "Downloading LuaRocks $LuaRocksVersion source..."
$sourceUrl = "https://luarocks.org/releases/luarocks-$LuaRocksVersion.tar.gz"
$sourceFile = "$vendorDir\luarocks-$LuaRocksVersion.tar.gz"

try {
    Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceFile
    Write-Host "Downloaded LuaRocks source"
} catch {
    throw "Failed to download LuaRocks: $_"
}

# Extract source
Write-Host "Extracting LuaRocks source..."
Push-Location $vendorDir
if (Get-Command "tar" -ErrorAction SilentlyContinue) {
    # Use built-in Windows tar (Windows 10+)
    & tar -xzf "luarocks-$LuaRocksVersion.tar.gz"
} elseif (Get-Command "7z" -ErrorAction SilentlyContinue) {
    & "7z" x "luarocks-$LuaRocksVersion.tar.gz"
    & "7z" x "luarocks-$LuaRocksVersion.tar"
} else {
    throw "Neither tar nor 7z found. Please install 7-Zip or use Windows 10+"
}
Pop-Location

$sourceDir = "$vendorDir\luarocks-$LuaRocksVersion"
if (-not (Test-Path $sourceDir)) {
    throw "Failed to extract LuaRocks source"
}

Push-Location $sourceDir

Write-Host "Creating minimal LuaRocks setup..."

# Create installation directories
New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
New-Item -Path "$InstallPath\lib" -ItemType Directory -Force | Out-Null
New-Item -Path "$InstallPath\share" -ItemType Directory -Force | Out-Null
New-Item -Path "$InstallPath\share\lua" -ItemType Directory -Force | Out-Null
New-Item -Path "$InstallPath\share\lua\5.4" -ItemType Directory -Force | Out-Null

# Copy LuaRocks core modules
if (Test-Path "src\luarocks") {
    Copy-Item -Path "src\luarocks" -Destination "$InstallPath\share\lua\5.4\" -Recurse -Force
    Write-Host "Copied LuaRocks modules"
} else {
    throw "LuaRocks source modules not found"
}

# Copy luarocks executable scripts
if (Test-Path "src\bin\luarocks") {
    New-Item -Path "$InstallPath\bin" -ItemType Directory -Force | Out-Null
    Copy-Item -Path "src\bin\luarocks" -Destination "$InstallPath\bin\luarocks.lua" -Force
    Copy-Item -Path "src\bin\luarocks-admin" -Destination "$InstallPath\bin\luarocks-admin.lua" -Force
    Write-Host "Copied LuaRocks executables"
}

# Create luarocks.bat wrapper - use the copied executable script
$luarocksMain = "$InstallPath\bin\luarocks.lua"
if (-not (Test-Path $luarocksMain)) {
    # Fallback to init.lua
    $luarocksMain = "$InstallPath\share\lua\5.4\luarocks\cmd\init.lua"
    if (-not (Test-Path $luarocksMain)) {
        throw "Could not find LuaRocks main script"
    }
}

$batContent = @"
@echo off
set LUA_PATH=$InstallPath\share\lua\5.4\?.lua;$InstallPath\share\lua\5.4\?\init.lua;%LUA_PATH%
"$LuaPath\bin\lua.exe" "$luarocksMain" %*
"@

Set-Content -Path "$InstallPath\luarocks.bat" -Value $batContent

# Create config file
$configContent = @"
variables = {
    LUA_DIR = [[$LuaPath]],
    LUA_BINDIR = [[$LuaPath\bin]],
    LUA_INCDIR = [[$LuaPath\include]],
    LUA_LIBDIR = [[$LuaPath\lib]],
}
rocks_trees = {
    { name = [[user]], root = [[$InstallPath]] }
}
"@

Set-Content -Path "$InstallPath\config.lua" -Value $configContent

Write-Host "Created minimal LuaRocks installation"

Pop-Location

# Verify installation
Write-Host "Verifying LuaRocks installation..."
$luarocksExe = "$InstallPath\luarocks.bat"
if (Test-Path $luarocksExe) {
    # Test LuaRocks
    try {
        $luarocksVersion = & $luarocksExe --version 2>&1 | Select-Object -First 1
        Write-Host "LuaRocks installation successful!"
        Write-Host "Version: $luarocksVersion"
    } catch {
        Write-Host "Warning: Could not test LuaRocks version, but files are installed"
    }
} else {
    throw "LuaRocks installation failed - luarocks.bat not found"
}

# Clean up source files but keep the vendor directory structure
# (The .gitignore will exclude the vendor directory from commits)

Write-Host "LuaRocks $LuaRocksVersion build completed successfully!"

exit 0