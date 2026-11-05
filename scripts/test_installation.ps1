[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$profile = Join-Path $repoRoot ('.screenshots\PackerMOD-InstallTest-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $profile | Out-Null
$protected = @('PackerMOD\packs\existing\worlds\world\map.sqlite', 'PackerMOD\cache\keep.bin', 'worlds\other\map.sqlite')
foreach ($relative in $protected) {
    $path = Join-Path $profile $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    Set-Content -LiteralPath $path -Value ('preserve:' + $relative)
}
Set-Content -LiteralPath (Join-Path $profile 'minetest.conf') -Value "main_menu_script = original-menu.lua`ncustom_setting = keep"
function Protected-Hashes {
    (@($protected | ForEach-Object { (Get-FileHash -LiteralPath (Join-Path $profile $_)).Hash }) -join ',')
}
$before = Protected-Hashes
& (Join-Path $repoRoot 'scripts\deploy_local.ps1') -UserData $profile
$sentinel = Join-Path $profile 'games\packerbase\old-version.txt'
Set-Content -LiteralPath $sentinel -Value 'backup me'
& (Join-Path $repoRoot 'scripts\deploy_local.ps1') -UserData $profile
if ((Protected-Hashes) -cne $before) { throw 'Protected test data changed' }
if (Test-Path -LiteralPath $sentinel) { throw 'Stale game file survived replacement' }
$backups = @(Get-ChildItem -LiteralPath (Join-Path $profile 'PackerMOD\install-backups') -Directory)
if ($backups.Count -ne 2 -or -not (Get-ChildItem -LiteralPath $backups[-1].FullName -Recurse -File | Where-Object { $_.Name -eq 'old-version.txt' })) { throw 'Previous game was not backed up' }
$config = Get-Content -LiteralPath (Join-Path $profile 'minetest.conf') -Raw
if ($config -notmatch '# packermod-backup main_menu_script = original-menu.lua' -or $config -notmatch 'custom_setting = keep') { throw 'Original configuration not preserved' }
# Developer Mode allows links; otherwise the installer verifies its copy fallback.
& (Join-Path $repoRoot 'install\install.ps1') -Mode symlink -UserData $profile
& (Join-Path $repoRoot 'scripts\deploy_local.ps1') -UserData $profile
if ((Get-Item -LiteralPath (Join-Path $profile 'PackerMOD\mainmenu')).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Symlink-to-copy transition failed' }
if ((Protected-Hashes) -cne $before) { throw 'Protected data changed during symlink transition' }
# An unmanaged game must cause failure before any menu/configuration is replaced.
$marker = Join-Path $profile 'games\packerbase\.packermod-managed'
Remove-Item -LiteralPath $marker
$configBefore = (Get-FileHash -LiteralPath (Join-Path $profile 'minetest.conf')).Hash
$rejected = $false
try { & (Join-Path $repoRoot 'install\install.ps1') -UserData $profile } catch {
    if ($_.Exception.Message -notmatch 'not managed') { throw }
    $rejected = $true
}
if (-not $rejected -or (Get-FileHash -LiteralPath (Join-Path $profile 'minetest.conf')).Hash -ne $configBefore) { throw 'Unmanaged game guard failed' }
# World files misplaced inside an owned game are also never overwritten.
Set-Content -LiteralPath $marker -Value 'test-managed'
$worldSentinel = Join-Path $profile 'games\packerbase\world.mt'
Set-Content -LiteralPath $worldSentinel -Value 'gameid = packerbase'
$rejected = $false
try { & (Join-Path $repoRoot 'install\install.ps1') -UserData $profile } catch {
    if ($_.Exception.Message -notmatch 'World data found') { throw }
    $rejected = $true
}
if (-not $rejected -or -not (Test-Path -LiteralPath $worldSentinel)) { throw 'Misplaced world guard failed' }
Write-Host 'PASS: install, repeat update, backup, deployed hashes, preserved data/config, symlink transition, unmanaged-game and world-data guards.'
Write-Host "Disposable test profile retained: $profile"
