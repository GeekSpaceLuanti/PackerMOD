[CmdletBinding()]
param(
    [string]$LuantiExe = 'C:\Users\bacon\AppData\Local\luanti\5.16.1\bin\luanti.exe'
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$userDir = Join-Path $env:APPDATA 'Luanti'
if (-not (Test-Path -LiteralPath $userDir)) { $userDir = Join-Path $env:APPDATA 'Minetest' }
$deployed = Join-Path $userDir 'PackerMOD'
if (-not (Test-Path -LiteralPath $LuantiExe)) { throw 'Windows Luanti executable not found' }
if (-not (Test-Path -LiteralPath (Join-Path $deployed 'mainmenu\init.lua'))) { throw 'Deployed PackerMOD not found' }
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('PackerMOD-WindowsTest-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testRoot | Out-Null
$outputDir = Join-Path $repoRoot '.screenshots'
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$logPath = Join-Path $outputDir ('windows-game-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log')
$config = Join-Path $testRoot 'minetest.conf'
$mainScript = Join-Path $PSScriptRoot 'windows_game_smoke_mainmenu.lua'
@("main_menu_script = $mainScript", "packermod_source_path = $deployed",
    'packermod_disposable_test = true', 'enable_sound = false', 'menu_clouds = false',
    'screen_w = 1280', 'screen_h = 800', 'fullscreen = false', 'language = ja') |
    Set-Content -LiteralPath $config -Encoding utf8
$startInfo = [Diagnostics.ProcessStartInfo]::new($LuantiExe)
$startInfo.UseShellExecute = $false
$startInfo.WindowStyle = 'Hidden'
foreach ($arg in @('--config', $config, '--logfile', $logPath)) { $startInfo.ArgumentList.Add($arg) }
$startInfo.Environment['LUANTI_USER_PATH'] = $testRoot
$startInfo.Environment['LUANTI_GAME_PATH'] = Join-Path $userDir 'games'
$testProcess = [Diagnostics.Process]::Start($startInfo)
try {
    if (-not $testProcess.WaitForExit(120000)) { throw 'Windows game test timed out' }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($testProcess.ExitCode -ne 0 -or $log -match 'ERROR\[' -or
        $log -notmatch 'Windows Minetest Game create and two launches verified') {
        throw "Windows game test failed. Log: $logPath"
    }
    Write-Host "Verified Windows Minetest Game Pack creation, Japanese world, two launches and recovery. Log: $logPath"
    Write-Host "Disposable profile retained: $testRoot"
} finally {
    if (-not $testProcess.HasExited) {
        # This process belongs solely to the disposable test profile.
        $null = $testProcess.CloseMainWindow()
        if (-not $testProcess.WaitForExit(3000)) { $testProcess.Kill() }
    }
    $testProcess.Dispose()
}
