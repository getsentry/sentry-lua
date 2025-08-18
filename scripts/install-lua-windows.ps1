# Simple PowerShell script to set up Lua environment for Windows CI
param(
    [Parameter(Mandatory=$true)]
    [string]$LuaVersion
)

$ErrorActionPreference = "Continue"  # Don't stop on errors, log them instead

Write-Host "Setting up Lua $LuaVersion for Windows CI..." -ForegroundColor Green

# Create base directory
$InstallDir = "C:\lua-ci"
New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null

if ($LuaVersion -match "luajit") {
    # Handle LuaJIT installation
    $luajitVersion = switch ($LuaVersion) {
        "luajit-2.0" { "v2.0.5" }
        "luajit-2.1" { "v2.1.0-beta3" }
        default { "v2.1.0-beta3" }
    }
    
    Write-Host "Installing LuaJIT $luajitVersion..." -ForegroundColor Yellow
    
    # Use working directory in temp
    $workDir = "$env:TEMP\luajit-build"
    if (Test-Path $workDir) { 
        Remove-Item $workDir -Recurse -Force -ErrorAction SilentlyContinue 
    }
    New-Item -ItemType Directory -Path $workDir -Force | Out-Null
    
    try {
        # Clone LuaJIT
        Set-Location $workDir
        Write-Host "Cloning LuaJIT..." -ForegroundColor Yellow
        $gitResult = & git clone --depth 1 --branch $luajitVersion https://github.com/LuaJIT/LuaJIT.git luajit 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Git clone failed: $gitResult" -ForegroundColor Red
            throw "Failed to clone LuaJIT"
        }
        
        # Build LuaJIT
        Set-Location "$workDir\luajit\src"
        Write-Host "Building LuaJIT..." -ForegroundColor Yellow
        & cmd /c msvcbuild.bat 2>&1 | Write-Host
        if ($LASTEXITCODE -ne 0) { 
            throw "Failed to build LuaJIT" 
        }
        
        # Create installation directory
        $luajitDir = "$InstallDir\luajit"
        New-Item -ItemType Directory -Path "$luajitDir\bin" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\include" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\lib" -Force | Out-Null
        
        # Copy built files
        Copy-Item "luajit.exe" "$luajitDir\bin\" -Force
        Copy-Item "lua51.dll" "$luajitDir\bin\" -Force
        Copy-Item "*.h" "$luajitDir\include\" -Force
        if (Test-Path "lua51.lib") { 
            Copy-Item "lua51.lib" "$luajitDir\lib\" -Force 
        }
        
        # Create lua.exe compatibility symlink
        Copy-Item "$luajitDir\bin\luajit.exe" "$luajitDir\bin\lua.exe" -Force
        
        # Set environment variables for GitHub Actions
        if ($env:GITHUB_ACTIONS -eq "true") {
            Add-Content -Path $env:GITHUB_PATH -Value "$luajitDir\bin" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_DIR=$luajitDir" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_INCDIR=$luajitDir\include" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_LIBDIR=$luajitDir\lib" -Encoding utf8
        }
        
        Write-Host "LuaJIT installation completed successfully" -ForegroundColor Green
        
    } catch {
        Write-Host "LuaJIT installation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Creating minimal LuaJIT environment for dependency builds..." -ForegroundColor Yellow
        
        # Create minimal structure for dependency compilation
        $luajitDir = "$InstallDir\luajit"
        New-Item -ItemType Directory -Path "$luajitDir\bin" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\include" -Force | Out-Null
        New-Item -ItemType Directory -Path "$luajitDir\lib" -Force | Out-Null
        
        # Create minimal headers
        @'
#ifndef LUA_H
#define LUA_H
#define LUA_VERSION_MAJOR "5"
#define LUA_VERSION_MINOR "1" 
#define LUA_VERSION_NUM 501
typedef struct lua_State lua_State;
typedef int (*lua_CFunction) (lua_State *L);
#endif
'@ | Out-File -FilePath "$luajitDir\include\lua.h" -Encoding utf8
        
        @'
#ifndef LAUXLIB_H
#define LAUXLIB_H
#include "lua.h"
#endif
'@ | Out-File -FilePath "$luajitDir\include\lauxlib.h" -Encoding utf8

        @'
#ifndef LUALIB_H  
#define LUALIB_H
#include "lua.h"
#endif
'@ | Out-File -FilePath "$luajitDir\include\lualib.h" -Encoding utf8
        
        if ($env:GITHUB_ACTIONS -eq "true") {
            Add-Content -Path $env:GITHUB_PATH -Value "$luajitDir\bin" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_DIR=$luajitDir" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_INCDIR=$luajitDir\include" -Encoding utf8
            Add-Content -Path $env:GITHUB_ENV -Value "LUA_LIBDIR=$luajitDir\lib" -Encoding utf8
        }
    } finally {
        # Return to script directory
        Set-Location $PSScriptRoot
    }
    
} else {
    # Handle standard Lua - create minimal environment for dependencies
    Write-Host "Setting up minimal Lua $LuaVersion environment for dependencies..." -ForegroundColor Yellow
    
    $luaDir = "$InstallDir\lua$LuaVersion"
    New-Item -ItemType Directory -Path "$luaDir\bin" -Force | Out-Null
    New-Item -ItemType Directory -Path "$luaDir\include" -Force | Out-Null
    New-Item -ItemType Directory -Path "$luaDir\lib" -Force | Out-Null
    
    # Extract version numbers
    $major = $LuaVersion.Split('.')[0]
    $minor = $LuaVersion.Split('.')[1]
    $versionNum = [int]$major * 100 + [int]$minor
    
    # Create minimal lua.h
    @"
#ifndef LUA_H
#define LUA_H
#define LUA_VERSION_MAJOR "$major"
#define LUA_VERSION_MINOR "$minor" 
#define LUA_VERSION_NUM $versionNum
typedef struct lua_State lua_State;
typedef int (*lua_CFunction) (lua_State *L);
#ifdef __cplusplus
extern "C" {
#endif
int lua_gettop (lua_State *L);
void lua_settop (lua_State *L, int idx);
#ifdef __cplusplus
}
#endif
#endif
"@ | Out-File -FilePath "$luaDir\include\lua.h" -Encoding utf8
    
    # Create minimal lauxlib.h
    @'
#ifndef LAUXLIB_H
#define LAUXLIB_H
#include "lua.h"
#ifdef __cplusplus
extern "C" {
#endif
int luaL_error (lua_State *L, const char *fmt, ...);
#ifdef __cplusplus
}
#endif
#endif
'@ | Out-File -FilePath "$luaDir\include\lauxlib.h" -Encoding utf8
    
    # Create minimal lualib.h
    @'
#ifndef LUALIB_H
#define LUALIB_H
#include "lua.h"
#endif
'@ | Out-File -FilePath "$luaDir\include\lualib.h" -Encoding utf8
    
    if ($env:GITHUB_ACTIONS -eq "true") {
        Add-Content -Path $env:GITHUB_PATH -Value "$luaDir\bin" -Encoding utf8
        Add-Content -Path $env:GITHUB_ENV -Value "LUA_DIR=$luaDir" -Encoding utf8
        Add-Content -Path $env:GITHUB_ENV -Value "LUA_INCDIR=$luaDir\include" -Encoding utf8
        Add-Content -Path $env:GITHUB_ENV -Value "LUA_LIBDIR=$luaDir\lib" -Encoding utf8
    }
    
    Write-Host "Minimal Lua $LuaVersion environment created" -ForegroundColor Green
}

# Install LuaRocks
Write-Host "Installing LuaRocks..." -ForegroundColor Yellow
try {
    $luarocksZip = "$env:TEMP\luarocks.zip"
    $luarocksUrl = "https://luarocks.github.io/luarocks/releases/luarocks-3.8.0-windows-64.zip"
    
    # Download LuaRocks
    Invoke-WebRequest -Uri $luarocksUrl -OutFile $luarocksZip -ErrorAction Stop
    
    # Extract LuaRocks
    $luarocksDir = "$InstallDir\luarocks"
    if (Test-Path $luarocksDir) { 
        Remove-Item $luarocksDir -Recurse -Force -ErrorAction SilentlyContinue 
    }
    Expand-Archive -Path $luarocksZip -DestinationPath $luarocksDir -Force
    
    # Find luarocks.exe
    $luarocksExe = Get-ChildItem -Path $luarocksDir -Recurse -Filter "luarocks.exe" | Select-Object -First 1
    if ($luarocksExe) {
        $luarocksPath = $luarocksExe.Directory.FullName
        
        if ($env:GITHUB_ACTIONS -eq "true") {
            Add-Content -Path $env:GITHUB_PATH -Value $luarocksPath -Encoding utf8
        }
        
        Write-Host "LuaRocks installed successfully to $luarocksPath" -ForegroundColor Green
    } else {
        Write-Host "Warning: LuaRocks executable not found after extraction" -ForegroundColor Yellow
    }
    
} catch {
    Write-Host "LuaRocks installation failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Dependencies may need to be installed manually" -ForegroundColor Yellow
}

Write-Host "Lua setup complete!" -ForegroundColor Green
Write-Host "Version: $LuaVersion" -ForegroundColor Cyan
Write-Host "Install directory: $InstallDir" -ForegroundColor Cyan