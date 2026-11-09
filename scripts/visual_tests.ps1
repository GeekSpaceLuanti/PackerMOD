[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu",
    [string]$LuantiBin = "",
    [switch]$Setup,
    [ValidateRange(800, 3840)][int]$Width = 1280,
    [ValidateRange(600, 2160)][int]$Height = 800,
    [string]$View = "all"
)
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if ($Setup) {
    & wsl -d $Distribution --cd $repoRoot -- bash scripts/setup_visual_tests.sh
    if ($LASTEXITCODE -ne 0) { throw "Visual test setup failed" }
}
$linuxArgs = @("-d", $Distribution, "--cd", $repoRoot, "--", "env", "WIN_W=$Width", "WIN_H=$Height")
if ($LuantiBin) { $linuxArgs += "LUANTI_BIN=$LuantiBin" }
if ($View -eq "all") {
    $linuxArgs += @("make", "screenshot-all")
} elseif ($View -match "^packerbase_(inventory|recipes|settings)$") {
    $linuxArgs += @("bash", "scripts/test_base_game_visual.sh", ".screenshots/${View}_${Width}x${Height}.png", $Matches[1])
} else {
    if ($View -notmatch "^[a-z0-9_]+$") { throw "Invalid view name" }
    $linuxArgs += @("bash", "scripts/screenshot_mainmenu.sh", $View, ".screenshots/${View}_${Width}x${Height}.png")
}
& wsl @linuxArgs
if ($LASTEXITCODE -ne 0) { throw "Visual tests failed" }
Write-Host "Screenshots: $(Join-Path $repoRoot '.screenshots')"

$outputDir = Join-Path $repoRoot '.screenshots'
$figures = Get-ChildItem -LiteralPath $outputDir -Filter '*.png' | Sort-Object Name | ForEach-Object {
    $name = [System.Net.WebUtility]::HtmlEncode($_.Name)
    "<figure><a href='$name'><img src='$name' loading='lazy'></a><figcaption>$name</figcaption></figure>"
}
$html = @"
<!doctype html><html lang='en'><meta charset='utf-8'><title>PackerMOD visual review</title>
<style>body{background:#13171d;color:#edf2f7;font:16px sans-serif;padding:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(360px,1fr));gap:20px}figure{margin:0}img{width:100%}figcaption{padding:8px;color:#98a5b3}</style>
<h1>PackerMOD visual review</h1><main>$($figures -join "`n")</main></html>
"@
Set-Content -LiteralPath (Join-Path $outputDir 'index.html') -Value $html -Encoding utf8
