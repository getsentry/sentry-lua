#!/usr/bin/env pwsh
#
# Install Windows Dependencies for Sentry Lua Testing
# Builds LuaRocks from source for Windows
#

param(
    [Parameter(Mandatory=$true)]
    [string]$LuaVersion,
    
    [Parameter(Mandatory=$true)]
    [string]$LuaPath
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Windows testing dependencies for Lua $LuaVersion"
Write-Host "Lua path: $LuaPath"

# Download LuaRocks source
Write-Host "Downloading LuaRocks source..."
$luarocksVersion = "3.11.1"
$sourceUrl = "https://luarocks.org/releases/luarocks-$luarocksVersion.tar.gz"
$sourceFile = "luarocks-$luarocksVersion.tar.gz"

Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceFile
Write-Host "Downloaded LuaRocks $luarocksVersion source"

# Extract source using tar (available in Windows 10+)
Write-Host "Extracting LuaRocks source..."
& tar -xzf $sourceFile

# Find the actual extracted directory
$extractedDirs = Get-ChildItem -Directory | Where-Object { $_.Name -match "luarocks" }
if ($extractedDirs) {
    $sourceDir = $extractedDirs[0].Name
    Write-Host "Found extracted directory: $sourceDir"
} else {
    throw "Failed to find extracted LuaRocks source directory"
}

if (-not (Test-Path $sourceDir)) {
    throw "Failed to extract LuaRocks source"
}

Push-Location $sourceDir

# Show what's in the directory
Write-Host "Contents of source directory:"
Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" }

# Check what's in src directory
Write-Host "Contents of src directory:"
if (Test-Path "src") {
    Get-ChildItem src | ForEach-Object { Write-Host "  src\$($_.Name)" }
}

# Check binary directory for Windows installer
Write-Host "Contents of binary directory:"
if (Test-Path "binary") {
    Get-ChildItem binary | ForEach-Object { Write-Host "  binary\$($_.Name)" }
}

# Look for Windows installer in binary directory first
$installScript = $null
if (Test-Path "binary\install.bat") {
    $installScript = "binary\install.bat"
    Write-Host "Found Windows installer: $installScript"
} elseif (Test-Path "install.bat") {
    $installScript = "install.bat"
    Write-Host "Found installer: $installScript"
} elseif (Test-Path "src\install.lua") {
    $installScript = "src\install.lua"
    Write-Host "Found install script: $installScript"
} elseif (Test-Path "install.lua") {
    $installScript = "install.lua" 
    Write-Host "Found install script: $installScript"
} else {
    Write-Host "No standard installer found, looking for alternatives..."
    # Look for any installer-like files
    $installers = Get-ChildItem -Recurse -Name "*install*" | Where-Object { $_ -match "\.(lua|bat|cmd)$" }
    if ($installers) {
        Write-Host "Found potential installers:"
        $installers | ForEach-Object { Write-Host "  $_" }
        $installScript = $installers[0]
        Write-Host "Using: $installScript"
    } else {
        throw "Could not find any installation script in LuaRocks source"
    }
}

# Configure and install LuaRocks
Write-Host "Installing LuaRocks for Lua $LuaVersion..."
$luarocksInstallPath = "C:\luarocks"

if ($installScript -match "\.bat$|\.cmd$") {
    # Windows batch file installer
    Write-Host "Using Windows batch installer: $installScript"
    $installArgs = @(
        "/P", $luarocksInstallPath,
        "/LUA", $LuaPath,
        "/LV", $LuaVersion,
        "/INC", "$LuaPath\include",
        "/LIB", "$LuaPath\lib", 
        "/BIN", "$LuaPath\bin"
    )
    Write-Host "Running: $installScript $($installArgs -join ' ')"
    & ".\$installScript" @installArgs
} elseif ($installScript -match "\.lua$") {
    # Lua installer script
    Write-Host "Using Lua installer script: $installScript"
    $installArgs = @(
        $installScript,
        "/FORCECONFIG",
        "/P", $luarocksInstallPath,
        "/LUA", $LuaPath,
        "/LV", $LuaVersion,
        "/INC", "$LuaPath\include",
        "/LIB", "$LuaPath\lib", 
        "/BIN", "$LuaPath\bin"
    )
    Write-Host "Running: $($LuaPath)\bin\lua.exe $($installArgs -join ' ')"
    & "$LuaPath\bin\lua.exe" @installArgs
} else {
    throw "Unknown installer type: $installScript"
}

if ($LASTEXITCODE -ne 0) {
    throw "LuaRocks configuration failed"
}

# Build and install LuaRocks
Write-Host "Building and installing LuaRocks..."
& "$LuaPath\bin\lua.exe" install.lua

if ($LASTEXITCODE -ne 0) {
    throw "LuaRocks installation failed"
}

Pop-Location

# Add LuaRocks to PATH
$luarocksExe = "$luarocksInstallPath\luarocks.bat"
if (Test-Path $luarocksExe) {
    Add-Content -Path $env:GITHUB_PATH -Value $luarocksInstallPath
    $env:PATH = "$luarocksInstallPath;$env:PATH"
    Write-Host "LuaRocks added to PATH: $luarocksExe"
} else {
    # Look for the actual executable
    $luarocksExe = Get-ChildItem -Path $luarocksInstallPath -Name "luarocks*" | Select-Object -First 1
    if ($luarocksExe) {
        $luarocksExe = Join-Path $luarocksInstallPath $luarocksExe
        Add-Content -Path $env:GITHUB_PATH -Value $luarocksInstallPath
        $env:PATH = "$luarocksInstallPath;$env:PATH"
        Write-Host "LuaRocks found: $luarocksExe"
    } else {
        throw "LuaRocks executable not found after installation"
    }
}

# Test LuaRocks installation
Write-Host "Testing LuaRocks installation..."
& luarocks --version
if ($LASTEXITCODE -ne 0) {
    throw "LuaRocks test failed"
}

Write-Host "LuaRocks installed successfully!"

# Install testing dependencies
Write-Host "Installing testing dependencies..."

# Install busted
Write-Host "Installing busted..."
& luarocks install busted
if ($LASTEXITCODE -ne 0) {
    throw "Failed to install busted"
}

# Install lua-cjson
Write-Host "Installing lua-cjson..."
& luarocks install lua-cjson
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: lua-cjson installation failed (may need compiler)"
}

# Install luasocket
Write-Host "Installing luasocket..."
& luarocks install luasocket
if ($LASTEXITCODE -ne 0) {
    Write-Host "Warning: luasocket installation failed (may need compiler)"
}

# Test busted
Write-Host "Testing busted installation..."
& busted --version
if ($LASTEXITCODE -eq 0) {
    Write-Host "Busted is working correctly"
} else {
    Write-Host "Warning: Busted version test failed"
}

# Clean up
Remove-Item -Path $sourceFile -Force -ErrorAction SilentlyContinue
Remove-Item -Path $sourceDir -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Windows testing environment ready!"
exit 0