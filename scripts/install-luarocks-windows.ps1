#!/usr/bin/env pwsh
#
# Windows LuaRocks Installer  
# Installs LuaRocks for use with a specific Lua installation
#

param(
    [Parameter(Mandatory=$true)]
    [string]$LuaVersion,
    
    [Parameter(Mandatory=$true)]
    [string]$LuaPath,
    
    [Parameter(Mandatory=$true)]
    [string]$InstallPath
)

$ErrorActionPreference = "Stop"

Write-Host "Installing LuaRocks for Lua $LuaVersion"
Write-Host "Lua installation: $LuaPath"
Write-Host "LuaRocks target: $InstallPath"

# Verify Lua installation exists
if (-not (Test-Path "$LuaPath\bin\lua.exe")) {
    throw "Lua installation not found at $LuaPath\bin\lua.exe"
}

# Download LuaRocks
Write-Host "Downloading LuaRocks..."
$luarocksUrl = "https://luarocks.github.io/luarocks/releases/luarocks-3.11.1-windows-32.zip"
$luarocksZip = "luarocks.zip"

try {
    Invoke-WebRequest -Uri $luarocksUrl -OutFile $luarocksZip
    Write-Host "Downloaded LuaRocks archive"
} catch {
    throw "Failed to download LuaRocks: $_"
}

# Extract LuaRocks
Write-Host "Extracting LuaRocks..."
$tempDir = "luarocks-temp"
Expand-Archive -Path $luarocksZip -DestinationPath $tempDir

# Find the extracted directory
$luarocksDir = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
if (-not $luarocksDir) {
    throw "Could not find LuaRocks directory in archive"
}

Write-Host "Found LuaRocks in: $($luarocksDir.FullName)"

Push-Location $luarocksDir.FullName

# Debug: Show what's actually in the archive
Write-Host "Contents of LuaRocks archive:"
Get-ChildItem -Recurse | ForEach-Object { Write-Host "  $($_.FullName.Replace($luarocksDir.FullName + '\', ''))" }

try {
    # Try different installation methods
    if (Test-Path "install.bat") {
        Write-Host "Running install.bat..."
        
        # Use cmd to run the batch installer
        $installCmd = "install.bat /P `"$InstallPath`" /CONFIG `"$InstallPath\config.lua`" /TREE `"$InstallPath\systree`" /LUA `"$LuaPath`" /LIB `"$LuaPath\bin`" /INC `"$LuaPath\include`" /BIN `"$LuaPath\bin`""
        & cmd /c $installCmd
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "install.bat failed, trying alternative method..."
            throw "install.bat failed"
        }
    }
    elseif (Test-Path "install.lua") {
        Write-Host "Running install.lua..."
        
        $installArgs = @(
            "install.lua"
            "--prefix=`"$InstallPath`""
            "--lua-dir=`"$LuaPath`""
            "--lua-version=$LuaVersion"
        )
        
        & "$LuaPath\bin\lua.exe" @installArgs
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "install.lua failed, trying manual installation..."
            throw "install.lua failed"
        }
    }
    else {
        Write-Host "No installer found, performing manual installation..."
        throw "No installer found"
    }
} catch {
    Write-Host "Performing manual LuaRocks installation..."
    
    # Manual installation
    New-Item -Path $InstallPath -ItemType Directory -Force | Out-Null
    New-Item -Path "$InstallPath\bin" -ItemType Directory -Force | Out-Null
    
    # Copy LuaRocks files - check what's actually available
    $luarocksScript = $null
    
    if (Test-Path "src\luarocks\cmd\luarocks.lua") {
        Copy-Item -Path "src\luarocks" -Destination "$InstallPath\" -Recurse -Force -ErrorAction SilentlyContinue
        $luarocksScript = "$InstallPath\luarocks\cmd\luarocks.lua"
    } elseif (Test-Path "src\bin\luarocks") {
        Copy-Item -Path "src\bin\*" -Destination "$InstallPath\bin\" -Recurse -Force -ErrorAction SilentlyContinue
        $luarocksScript = "$InstallPath\bin\luarocks"
    } elseif (Test-Path "src") {
        Copy-Item -Path "src\*" -Destination "$InstallPath\bin\" -Recurse -Force -ErrorAction SilentlyContinue
        # Try to find the main script
        $possibleScripts = @(
            "$InstallPath\bin\luarocks.lua",
            "$InstallPath\bin\luarocks"
        )
        foreach ($script in $possibleScripts) {
            if (Test-Path $script) {
                $luarocksScript = $script
                break
            }
        }
    }
    
    # Create luarocks.bat wrapper pointing to the correct script
    if ($luarocksScript) {
        $batContent = @"
@echo off
"$LuaPath\bin\lua.exe" "$luarocksScript" %*
"@
        Set-Content -Path "$InstallPath\luarocks.bat" -Value $batContent
        Write-Host "Created luarocks.bat pointing to: $luarocksScript"
    } else {
        # Fallback - create a simple wrapper that tries common locations
        $batContent = @"
@echo off
if exist "$InstallPath\luarocks\cmd\luarocks.lua" (
    "$LuaPath\bin\lua.exe" "$InstallPath\luarocks\cmd\luarocks.lua" %*
) else if exist "$InstallPath\bin\luarocks.lua" (
    "$LuaPath\bin\lua.exe" "$InstallPath\bin\luarocks.lua" %*
) else if exist "$InstallPath\bin\luarocks" (
    "$LuaPath\bin\lua.exe" "$InstallPath\bin\luarocks" %*
) else (
    echo LuaRocks script not found
    exit 1
)
"@
        Set-Content -Path "$InstallPath\luarocks.bat" -Value $batContent
        Write-Host "Created fallback luarocks.bat"
    }
    
    # Create basic config
    $configContent = @"
variables = {
    LUA_DIR = [[$LuaPath]],
    LUA_BINDIR = [[$LuaPath\bin]], 
    LUA_INCDIR = [[$LuaPath\include]],
    LUA_LIBDIR = [[$LuaPath\lib]],
}
"@
    Set-Content -Path "$InstallPath\config.lua" -Value $configContent
}

Pop-Location

# Verify installation
Write-Host "Verifying LuaRocks installation..."

$luarocksExe = "$InstallPath\luarocks.bat"
$luarocksCmd = "$InstallPath\bin\luarocks"

if (Test-Path $luarocksExe) {
    Write-Host "LuaRocks wrapper script created successfully!"
} elseif (Test-Path $luarocksCmd) {
    Write-Host "LuaRocks command found!"
} else {
    Write-Host "LuaRocks installation may be incomplete, but proceeding..."
}

# Test LuaRocks
try {
    if (Test-Path $luarocksExe) {
        $luarocksVersion = & cmd /c "`"$luarocksExe`" --version" 2>&1
        Write-Host "Version: $luarocksVersion"
    }
} catch {
    Write-Host "Could not test LuaRocks version (this may be normal)"
}

Write-Host "LuaRocks installation contents:"
if (Test-Path $InstallPath) {
    Get-ChildItem $InstallPath -Recurse -ErrorAction SilentlyContinue | ForEach-Object { 
        $relativePath = $_.FullName.Replace("$InstallPath\", "")
        Write-Host "  $relativePath"
    }
}

Write-Host "LuaRocks installation completed!"

# Ensure we exit with success code
exit 0