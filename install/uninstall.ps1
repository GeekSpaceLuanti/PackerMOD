$ErrorActionPreference = "Stop"

$userData       = Join-Path $env:APPDATA "Luanti"
$conf           = Join-Path $userData "minetest.conf"
$targetMainmenu = Join-Path $userData "PackerMOD\mainmenu"

if (Test-Path $targetMainmenu) {
    Remove-Item -Recurse -Force $targetMainmenu
    Write-Host "Removed $targetMainmenu"
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

Write-Host "Uninstalled. packs/ and cache/ left in place under $userData\PackerMOD."
