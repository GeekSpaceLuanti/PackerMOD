[CmdletBinding()]
param(
    [ValidateSet("copy", "symlink")]
    [string]$Mode = "copy"
)
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$userData = Join-Path $env:APPDATA "Luanti"

if (-not (Test-Path $userData)) {
    Write-Error "Luanti user data directory not found: $userData. Run Luanti once to create it."
}

$targetRoot     = Join-Path $userData "PackerMOD"
$targetMainmenu = Join-Path $targetRoot "mainmenu"

New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot "packs") | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $targetRoot "cache") | Out-Null

if (Test-Path $targetMainmenu) {
    Remove-Item -Recurse -Force $targetMainmenu
}

$sourceMainmenu = Join-Path $repoRoot "mainmenu"

if ($Mode -eq "symlink") {
    try {
        New-Item -ItemType SymbolicLink -Path $targetMainmenu -Target $sourceMainmenu -ErrorAction Stop | Out-Null
        Write-Host "Linked $targetMainmenu -> $sourceMainmenu"
    } catch {
        Write-Warning "Symlink failed (requires Developer Mode or admin). Falling back to copy."
        Copy-Item -Recurse -Path $sourceMainmenu -Destination $targetMainmenu
        Write-Host "Copied $sourceMainmenu -> $targetMainmenu"
    }
} else {
    Copy-Item -Recurse -Path $sourceMainmenu -Destination $targetMainmenu
    Write-Host "Copied $sourceMainmenu -> $targetMainmenu"
}

$conf = Join-Path $userData "minetest.conf"
$absInit = Join-Path $targetMainmenu "init.lua"

if (-not (Test-Path $conf)) {
    New-Item -ItemType File -Force -Path $conf | Out-Null
}

$content = Get-Content $conf -Raw
if ($null -eq $content) { $content = "" }

if ($content -match "(?m)^main_menu_script") {
    if ($content -notmatch "(?m)^# packermod-backup main_menu_script") {
        $content = $content -replace "(?m)^main_menu_script", "# packermod-backup main_menu_script"
    }
    $content = $content -replace "(?m)^main_menu_script .*\r?\n?", ""
}

if (-not $content.EndsWith("`n")) { $content += "`n" }
$content += "main_menu_script = $absInit`n"

Set-Content -Path $conf -Value $content -NoNewline -Encoding UTF8

Write-Host "Wrote main_menu_script = $absInit to $conf"
Write-Host "Done. Start Luanti to load the PackerMOD main menu."
