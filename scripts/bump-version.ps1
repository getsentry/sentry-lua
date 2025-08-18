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

# Update LuaRocks file - need to create a new one with proper version
$oldRockspec = Get-ChildItem "$repoRoot/*.rockspec" | Select-Object -First 1
if ($oldRockspec) {
    $newRockspecName = "sentry-lua-$newVersion-1.rockspec"
    Write-Host "Creating new rockspec: $newRockspecName"
    
    $content = Get-Content $oldRockspec.FullName -Raw
    $content = $content -replace 'version = ".*?"', "version = `"$newVersion-1`""
    $content | Set-Content "$repoRoot/$newRockspecName" -Encoding UTF8NoBOM
    
    # Remove old rockspec if it's not the dev version
    if ($oldRockspec.Name -ne "sentry-lua-dev-1.rockspec") {
        Remove-Item $oldRockspec.FullName
        Write-Host "Removed old rockspec: $($oldRockspec.Name)"
    }
}

# Update all Teal source files with version references
$tealFiles = @(
    "src/sentry/core/test_transport.tl",
    "src/sentry/utils/dsn.tl", 
    "src/sentry/core/file_transport.tl",
    "src/sentry/utils/serialize.tl",
    "src/sentry/platforms/nginx/transport.tl",
    "src/sentry/platforms/standard/file_transport.tl",
    "src/sentry/platforms/standard/transport.tl",
    "src/sentry/platforms/defold/transport.tl",
    "src/sentry/platforms/redis/transport.tl",
    "src/sentry/platforms/test/transport.tl",
    "src/sentry/platforms/roblox/transport.tl",
    "src/sentry/platforms/love2d/transport.tl"
)

foreach ($file in $tealFiles) {
    Replace-TextInFile "$repoRoot/$file" '\d+\.\d+\.\d+' $newVersion
}

# Update test spec files
Replace-TextInFile "$repoRoot/spec/sentry_spec.lua" '(?<=sentry\.set_tag\("version", ").*?(?=")' $newVersion

Write-Host "Version bump completed successfully to $newVersion"
Write-Host "Please run 'make build' to rebuild the Lua files from Teal sources"