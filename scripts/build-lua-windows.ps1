#!/usr/bin/env pwsh
#
# Windows Lua Builder
# Builds Lua from official source using Visual Studio compiler
#

param(
    [Parameter(Mandatory=$true)]
    [string]$LuaVersion,
    
    [Parameter(Mandatory=$true)]
    [string]$InstallPath
)

$ErrorActionPreference = "Stop"

Write-Host "Building Lua $LuaVersion for Windows"
Write-Host "Installation target: $InstallPath"

# Map version to full version number for downloads
$versionMap = @{
    "5.1" = "5.1.5"
    "5.2" = "5.2.4" 
    "5.3" = "5.3.6"
    "5.4" = "5.4.8"
}

$fullVersion = $versionMap[$LuaVersion]
if (-not $fullVersion) {
    throw "Unsupported Lua version: $LuaVersion"
}

Write-Host "Downloading Lua $fullVersion from official source..."

# Create vendor directory for source downloads
$vendorDir = "vendor\lua-$LuaVersion"
New-Item -Path $vendorDir -ItemType Directory -Force | Out-Null

# Download official Lua source
$sourceUrl = "https://www.lua.org/ftp/lua-$fullVersion.tar.gz"
$sourceFile = "$vendorDir\lua-$fullVersion.tar.gz"

try {
    Invoke-WebRequest -Uri $sourceUrl -OutFile $sourceFile
    Write-Host "Downloaded $sourceFile"
} catch {
    throw "Failed to download Lua source: $_"
}

# Extract source
Write-Host "Extracting source..."
Push-Location $vendorDir
if (Get-Command "7z" -ErrorAction SilentlyContinue) {
    & "7z" x "lua-$fullVersion.tar.gz"
    & "7z" x "lua-$fullVersion.tar"
} elseif (Get-Command "tar" -ErrorAction SilentlyContinue) {
    # Use built-in Windows tar (Windows 10+)
    & tar -xzf "lua-$fullVersion.tar.gz"
} else {
    throw "Neither 7z nor tar found. Please install 7-Zip or use Windows 10+"
}
Pop-Location

$sourceDir = "$vendorDir\lua-$fullVersion"
if (-not (Test-Path $sourceDir)) {
    throw "Failed to extract Lua source"
}

# Create installation directories
Write-Host "Creating installation directories..."
New-Item -Path "$InstallPath\bin" -ItemType Directory -Force | Out-Null
New-Item -Path "$InstallPath\include" -ItemType Directory -Force | Out-Null  
New-Item -Path "$InstallPath\lib" -ItemType Directory -Force | Out-Null

# Find and set up Visual Studio environment
Write-Host "Looking for Visual Studio compiler..."

# Try to find Visual Studio in common locations
$vsBasePaths = @(
    "${env:ProgramFiles}\Microsoft Visual Studio",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio"
)

$vcvarsPath = $null
foreach ($basePath in $vsBasePaths) {
    if (Test-Path $basePath) {
        $vsVersions = Get-ChildItem $basePath -Directory | Sort-Object Name -Descending
        foreach ($version in $vsVersions) {
            $editions = @("Enterprise", "Professional", "Community", "BuildTools")
            foreach ($edition in $editions) {
                $candidatePath = "$($version.FullName)\$edition\VC\Auxiliary\Build\vcvars64.bat"
                if (Test-Path $candidatePath) {
                    $vcvarsPath = $candidatePath
                    Write-Host "Found Visual Studio at: $candidatePath"
                    break
                }
            }
            if ($vcvarsPath) { break }
        }
    }
    if ($vcvarsPath) { break }
}

if (-not $vcvarsPath) {
    throw "Visual Studio compiler not found. Please install Visual Studio with C++ support."
}

# Build Lua using Visual Studio compiler
Push-Location "$sourceDir\src"

Write-Host "Compiling Lua source files..."

# Set up Visual Studio environment variables in current PowerShell session
& cmd /c "`"$vcvarsPath`" && set" | ForEach-Object {
    if ($_ -match "^(.+?)=(.*)$") {
        [System.Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
    }
}

$versionNoDots = $LuaVersion.Replace('.', '')
$luaLib = "lua$versionNoDots.lib"
$luaDll = "lua$versionNoDots.dll"

# Compile all C source files
Write-Host "Compiling C source files..."
& cl /MD /O2 /c /DLUA_BUILD_AS_DLL *.c
if ($LASTEXITCODE -ne 0) {
    throw "C compilation failed with exit code $LASTEXITCODE"
}

# Create static library (exclude main function objects)
Write-Host "Creating static library $luaLib..."
$libObjects = Get-ChildItem -Name "*.obj" | Where-Object { $_ -ne "lua.obj" -and $_ -ne "luac.obj" }
$libObjList = $libObjects -join " "
& cmd /c "lib /out:$luaLib $libObjList"
if ($LASTEXITCODE -ne 0) {
    throw "Library creation failed with exit code $LASTEXITCODE"
}

# Create DLL (exclude main function objects)
Write-Host "Creating DLL $luaDll..."
& cmd /c "link /DLL /out:$luaDll $libObjList"
if ($LASTEXITCODE -ne 0) {
    throw "DLL creation failed with exit code $LASTEXITCODE"
}

# Create executables
Write-Host "Creating executables..."
& link /out:lua.exe lua.obj $luaLib
if ($LASTEXITCODE -ne 0) {
    throw "lua.exe creation failed with exit code $LASTEXITCODE"
}

# For luac.exe, we need all objects except lua.obj (luac needs more symbols)
$luacObjects = Get-ChildItem -Name "*.obj" | Where-Object { $_ -ne "lua.obj" }
$luacObjList = $luacObjects -join " "
& cmd /c "link /out:luac.exe $luacObjList"
if ($LASTEXITCODE -ne 0) {
    throw "luac.exe creation failed with exit code $LASTEXITCODE"
}

Write-Host "Build completed successfully!"

Write-Host "Installing files..."

# Install files
Copy-Item -Path "lua.exe" -Destination "$InstallPath\bin\"
Copy-Item -Path "luac.exe" -Destination "$InstallPath\bin\"
Copy-Item -Path "lua$versionNoDots.dll" -Destination "$InstallPath\bin\"
Copy-Item -Path "lua$versionNoDots.lib" -Destination "$InstallPath\lib\"
Copy-Item -Path "*.h" -Destination "$InstallPath\include\"

Pop-Location

# Verify installation
Write-Host "Verifying installation..."
$luaExe = "$InstallPath\bin\lua.exe"
if (Test-Path $luaExe) {
    # Test with a simple command that works across all Lua versions
    $versionOutput = & $luaExe -e "print(_VERSION)" 2>&1
    Write-Host "Lua installation successful!"
    Write-Host "Version: $versionOutput"
    
    Write-Host "Installed files:"
    Get-ChildItem "$InstallPath\bin\" | ForEach-Object { Write-Host "  bin\$($_.Name)" }
    Get-ChildItem "$InstallPath\lib\" | ForEach-Object { Write-Host "  lib\$($_.Name)" }
    Get-ChildItem "$InstallPath\include\" | ForEach-Object { Write-Host "  include\$($_.Name)" }
} else {
    throw "Lua installation failed - lua.exe not found"
}

Write-Host "Lua $LuaVersion build completed successfully!"

# Ensure we exit with success code
exit 0