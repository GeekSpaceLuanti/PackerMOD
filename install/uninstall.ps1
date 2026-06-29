$ErrorActionPreference = "Stop"

$userData         = Join-Path $env:APPDATA "Luanti"
$conf             = Join-Path $userData "minetest.conf"
$targetMainmenu   = Join-Path $userData "PackerMOD\mainmenu"
$targetPmTextures = Join-Path $userData "PackerMOD\textures"
$userTextures     = Join-Path $userData "textures"

if (Test-Path $targetMainmenu) {
    Remove-Item -Recurse -Force $targetMainmenu
    Write-Host "Removed $targetMainmenu"
}

if (Test-Path $targetPmTextures) {
    Remove-Item -Recurse -Force $targetPmTextures
    Write-Host "Removed $targetPmTextures"
}

# 過去の install スクリプトが <user>\textures\packermod_*.png に置いていたものを掃除
if (Test-Path $userTextures) {
    Get-ChildItem -Path $userTextures -Filter "packermod_*.png" -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item -Force $_.FullName }
}

if (Test-Path $conf) {
    $content = Get-Content $conf -Raw
    if ($null -ne $content) {
        $content = $content -replace "(?m)^main_menu_script .*\r?\n?", ""
        $content = $content -replace "(?m)^# packermod-backup main_menu_script", "main_menu_script"
        Set-Content -Path $conf -Value $content -NoNewline -Encoding UTF8
    }
    Write-Host "Restored $conf"
}

Write-Host "Uninstalled. packs\ and cache\ left in place under $userData\PackerMOD."
Write-Host "(They contain your Packs and downloaded ContentDB cache. Delete manually if unwanted.)"
