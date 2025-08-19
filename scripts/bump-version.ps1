param([string] $newVersion)

if (-not $newVersion) {
    Write-Error "New version parameter is required"
    exit 1
}

if (-not ($newVersion -match '^\d+\.\d+\.\d+$')) {
    Write-Error "Version must be in format x.y.z (e.g., 1.0.0)"
    exit 1
}

Write-Host "Bumping version to $newVersion"

$utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False) 

function Replace-TextInFile {
    param([string] $filePath, [string] $pattern, [string] $replacement)
    
    if (-not (Test-Path $filePath)) {
        Write-Warning "File not found: $filePath"
        return
    }
    
    Write-Host "Updating $filePath"
    $content = [IO.File]::ReadAllText($filePath)
    $content = [Text.RegularExpressions.Regex]::Replace($content, $pattern, $replacement)
    [IO.File]::WriteAllText($filePath, $content, $utf8NoBomEncoding)
}

$repoRoot = "$PSScriptRoot/.."

# Update tealdoc.yml
Replace-TextInFile "$repoRoot/tealdoc.yml" '(?<=project_version: ").*?(?=")' $newVersion

# Update roblox.json
Replace-TextInFile "$repoRoot/roblox.json" '(?<="version": ").*?(?=")' $newVersion

# Update README.md
Replace-TextInFile "$repoRoot/README.md" '(?<=release = ").*?(?=")' $newVersion

# Update LuaRocks file - update existing rockspec version and rename file
$rockspec = Get-ChildItem "$repoRoot/*.rockspec" | Select-Object -First 1
if ($rockspec) {
    Write-Host "Updating rockspec: $($rockspec.Name)"
    Replace-TextInFile $rockspec.FullName '(?<=version = ").*?(?=")' "$newVersion-1"
    
    # Rename rockspec file to match new version
    $newRockspecName = "sentry-lua-$newVersion-1.rockspec"
    $newRockspecPath = "$repoRoot/$newRockspecName"
    
    if ($rockspec.Name -ne $newRockspecName) {
        Write-Host "Renaming rockspec from $($rockspec.Name) to $newRockspecName"
        Move-Item $rockspec.FullName $newRockspecPath
    }
}

# Update centralized version file
Replace-TextInFile "$repoRoot/src/sentry/version.tl" '(?<=VERSION = ").*?(?=")' $newVersion

# Update test spec files
Replace-TextInFile "$repoRoot/spec/sentry_spec.lua" '(?<=sentry\.set_tag\("version", ").*?(?=")' $newVersion

Write-Host "Version bump completed successfully to $newVersion"
Write-Host "Please run 'make build' to rebuild the Lua files from Teal sources"