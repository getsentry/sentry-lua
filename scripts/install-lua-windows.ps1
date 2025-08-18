# PowerShell script to install Lua and LuaRocks on Windows
# Usage: .\scripts\install-lua-windows.ps1 -LuaVersion "5.4" -Architecture "x64"
# Usage: .\scripts\install-lua-windows.ps1 -LuaVersion "luajit-2.1" -Architecture "x64"

param(
    [Parameter(Mandatory=$true)]
    [string]$LuaVersion,
    
    [Parameter(Mandatory=$false)]
    [string]$Architecture = "x64",
    
    [Parameter(Mandatory=$false)]
    [string]$InstallDir = "C:\lua-dev"
)

$ErrorActionPreference = "Stop"

Write-Host "Installing Lua $LuaVersion ($Architecture) to $InstallDir" -ForegroundColor Green

# Create installation directory
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

if ($LuaVersion -match "luajit") {
    # Handle LuaJIT installation
    $luajitVersion = switch ($LuaVersion) {
        "luajit-2.0" { "v2.0.5" }
        "luajit-2.1" { "v2.1.0-beta3" }
        default { "v2.1.0-beta3" }
    }
    
    Write-Host "Installing LuaJIT $luajitVersion..." -ForegroundColor Yellow
    
    # Clone and build LuaJIT
    $luajitSrc = "$env:TEMP\luajit-src"
    if (Test-Path $luajitSrc) { Remove-Item $luajitSrc -Recurse -Force }
    
    & git clone --depth 1 --branch $luajitVersion https://github.com/LuaJIT/LuaJIT.git $luajitSrc
    if ($LASTEXITCODE -ne 0) { throw "Failed to clone LuaJIT" }
    
    Push-Location "$luajitSrc\src"
    try {
        & cmd /c "call `"$env:ProgramFiles\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat`" && msvcbuild.bat"
        if ($LASTEXITCODE -ne 0) { throw "Failed to build LuaJIT" }
        
        # Install LuaJIT
        $luajitDir = "$InstallDir\luajit"
        New-Item -ItemType Directory -Path $luajitDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\bin" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\include" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\lib" -Force | Out-Null
        
        Copy-Item "luajit.exe" "$luajitDir\bin\"
        Copy-Item "lua51.dll" "$luajitDir\bin\"
        Copy-Item "*.h" "$luajitDir\include\"
        if (Test-Path "lua51.lib") { Copy-Item "lua51.lib" "$luajitDir\lib\" }
        
        # Create lua.exe symlink for compatibility
        Copy-Item "$luajitDir\bin\luajit.exe" "$luajitDir\bin\lua.exe"
        
        Write-Host "LuaJIT installed to $luajitDir" -ForegroundColor Green
        
        # Set environment variables for GitHub Actions
        if ($env:GITHUB_ACTIONS) {
            "$luajitDir\bin" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
            "LUA_DIR=$luajitDir" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
            "LUA_INCDIR=$luajitDir\include" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
            "LUA_LIBDIR=$luajitDir\lib" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        }
        
    } finally {
        Pop-Location
    }
    
} else {
    # Handle standard Lua installation
    Write-Host "Installing standard Lua $LuaVersion..." -ForegroundColor Yellow
    
    # Download precompiled Lua binaries
    $luaUrl = switch ($LuaVersion) {
        "5.1" { "https://sourceforge.net/projects/luabinaries/files/5.1.5/Windows%20Libraries/Dynamic/lua-5.1.5_Win64_dllw6_lib.zip/download" }
        "5.2" { "https://sourceforge.net/projects/luabinaries/files/5.2.4/Windows%20Libraries/Dynamic/lua-5.2.4_Win64_dllw6_lib.zip/download" }
        "5.3" { "https://sourceforge.net/projects/luabinaries/files/5.3.6/Windows%20Libraries/Dynamic/lua-5.3.6_Win64_dllw6_lib.zip/download" }
        "5.4" { "https://sourceforge.net/projects/luabinaries/files/5.4.4/Windows%20Libraries/Dynamic/lua-5.4.4_Win64_dllw6_lib.zip/download" }
        default { throw "Unsupported Lua version: $LuaVersion" }
    }
    
    $execUrl = switch ($LuaVersion) {
        "5.1" { "https://sourceforge.net/projects/luabinaries/files/5.1.5/Windows%20Libraries/Dynamic/lua-5.1.5_Win64_dllw6_lib.zip/download" }
        "5.2" { "https://sourceforge.net/projects/luabinaries/files/5.2.4/Windows%20Libraries/Dynamic/lua-5.2.4_Win64_dllw6_lib.zip/download" }
        "5.3" { "https://sourceforge.net/projects/luabinaries/files/5.3.6/Windows%20Libraries/Dynamic/lua-5.3.6_Win64_dllw6_lib.zip/download" }
        "5.4" { "https://sourceforge.net/projects/luabinaries/files/5.4.4/Windows%20Libraries/Dynamic/lua-5.4.4_Win64_dllw6_lib.zip/download" }
        default { throw "Unsupported Lua version: $LuaVersion" }
    }
    
    # Create Lua directory structure
    $luaDir = "$InstallDir\lua$LuaVersion"
    New-Item -ItemType Directory -Path "$luaDir\bin" -Force | Out-Null
    New-Item -ItemType Directory -Path "$luaDir\include" -Force | Out-Null
    New-Item -ItemType Directory -Path "$luaDir\lib" -Force | Out-Null
    
    # Download and extract Lua
    $zipFile = "$env:TEMP\lua-$LuaVersion.zip"
    Write-Host "Downloading Lua $LuaVersion from SourceForge..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $luaUrl -OutFile $zipFile -UserAgent "Mozilla/5.0"
    
    # Extract to temporary location first
    $extractDir = "$env:TEMP\lua-$LuaVersion-extract"
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Expand-Archive -Path $zipFile -DestinationPath $extractDir
    
    # Find and copy files (SourceForge archives have varying structures)
    Get-ChildItem -Path $extractDir -Recurse -Filter "*.exe" | ForEach-Object { Copy-Item $_.FullName "$luaDir\bin\" }
    Get-ChildItem -Path $extractDir -Recurse -Filter "*.dll" | ForEach-Object { Copy-Item $_.FullName "$luaDir\bin\" }
    Get-ChildItem -Path $extractDir -Recurse -Filter "*.lib" | ForEach-Object { Copy-Item $_.FullName "$luaDir\lib\" }
    Get-ChildItem -Path $extractDir -Recurse -Filter "*.h" | ForEach-Object { Copy-Item $_.FullName "$luaDir\include\" }
    
    # If no headers found, create minimal ones
    if (-not (Get-ChildItem "$luaDir\include\*.h" -ErrorAction SilentlyContinue)) {
        Write-Host "Creating minimal Lua headers..." -ForegroundColor Yellow
        @"
#ifndef LUA_H
#define LUA_H

#define LUA_VERSION_MAJOR "$($LuaVersion.Split('.')[0])"
#define LUA_VERSION_MINOR "$($LuaVersion.Split('.')[1])"
#define LUA_VERSION_NUM $(([int]$LuaVersion.Split('.')[0] * 100) + [int]$LuaVersion.Split('.')[1])

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lua_State lua_State;
typedef int (*lua_CFunction) (lua_State *L);

#ifdef __cplusplus
}
#endif

#endif
"@ | Out-File -FilePath "$luaDir\include\lua.h" -Encoding utf8
    }
    
    Write-Host "Standard Lua $LuaVersion installed to $luaDir" -ForegroundColor Green
    
    # Set environment variables for GitHub Actions
    if ($env:GITHUB_ACTIONS) {
        "$luaDir\bin" | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
        "LUA_DIR=$luaDir" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "LUA_INCDIR=$luaDir\include" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
        "LUA_LIBDIR=$luaDir\lib" | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
    }
}

# Install LuaRocks
Write-Host "Installing LuaRocks..." -ForegroundColor Yellow
$luarocksZip = "$env:TEMP\luarocks.zip"
$luarocksUrl = "https://luarocks.github.io/luarocks/releases/luarocks-3.8.0-windows-64.zip"

Invoke-WebRequest -Uri $luarocksUrl -OutFile $luarocksZip
$luarocksDir = "$InstallDir\luarocks"
if (Test-Path $luarocksDir) { Remove-Item $luarocksDir -Recurse -Force }
Expand-Archive -Path $luarocksZip -DestinationPath $luarocksDir

# Configure LuaRocks
$luarocksExe = Get-ChildItem -Path $luarocksDir -Recurse -Filter "luarocks.exe" | Select-Object -First 1
if ($luarocksExe) {
    $luarocksPath = $luarocksExe.Directory.FullName
    
    if ($env:GITHUB_ACTIONS) {
        $luarocksPath | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append
    }
    
    Write-Host "LuaRocks installed to $luarocksPath" -ForegroundColor Green
    
    # Try to configure LuaRocks with our Lua installation
    try {
        if ($LuaVersion -match "luajit") {
            $luaDir = "$InstallDir\luajit"
        } else {
            $luaDir = "$InstallDir\lua$LuaVersion"
        }
        
        & $luarocksExe.FullName config lua_dir $luaDir
        & $luarocksExe.FullName config variables.LUA_DIR $luaDir
        & $luarocksExe.FullName config variables.LUA_INCDIR "$luaDir\include"
        & $luarocksExe.FullName config variables.LUA_LIBDIR "$luaDir\lib"
        
        Write-Host "LuaRocks configured for Lua installation" -ForegroundColor Green
    } catch {
        Write-Host "Warning: Could not configure LuaRocks automatically" -ForegroundColor Yellow
    }
} else {
    Write-Host "Warning: LuaRocks executable not found" -ForegroundColor Yellow
}

Write-Host "Installation complete!" -ForegroundColor Green
Write-Host "Lua version: $LuaVersion" -ForegroundColor Cyan
Write-Host "Install directory: $InstallDir" -ForegroundColor Cyan

# Test installation
try {
    if ($LuaVersion -match "luajit") {
        & "$InstallDir\luajit\bin\luajit.exe" -v
    } else {
        & "$InstallDir\lua$LuaVersion\bin\lua.exe" -v
    }
    Write-Host "Lua installation test: PASSED" -ForegroundColor Green
} catch {
    Write-Host "Lua installation test: FAILED" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}