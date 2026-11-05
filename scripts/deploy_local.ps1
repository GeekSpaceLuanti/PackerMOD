[CmdletBinding()]
param([string]$UserData)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (Get-Process -Name luanti, minetest -ErrorAction SilentlyContinue) { throw 'Luanti is running. Close it normally before deploying.' }
if (-not $UserData) {
    $UserData = Join-Path $env:APPDATA 'Luanti'
    if (-not (Test-Path -LiteralPath $UserData)) { $UserData = Join-Path $env:APPDATA 'Minetest' }
}
if (-not (Test-Path -LiteralPath $UserData -PathType Container)) { throw 'Luanti user data not found' }
$UserData = [IO.Path]::GetFullPath($UserData)
$installRoot = Join-Path $UserData 'PackerMOD'
$protectedRoots = @((Join-Path $installRoot 'packs'), (Join-Path $installRoot 'cache'), (Join-Path $UserData 'worlds'))
function Get-ProtectedState {
    @($protectedRoots | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            Get-ChildItem -LiteralPath $_ -Recurse -Force -File | ForEach-Object {
                [pscustomobject]@{ Path=$_.FullName; Length=$_.Length; Hash=(Get-FileHash -LiteralPath $_.FullName).Hash }
            }
        }
    } | Sort-Object Path) | ConvertTo-Json -Depth 3 -Compress
}
$before = Get-ProtectedState
& (Join-Path $repoRoot 'install\install.ps1') -Mode copy -UserData $UserData
if ((Get-ProtectedState) -cne $before) { throw 'Protected Pack, world or cache data changed during deployment' }
foreach ($part in @(
    @{ Source=(Join-Path $repoRoot 'mainmenu'); Target=(Join-Path $installRoot 'mainmenu') },
    @{ Source=(Join-Path $repoRoot 'textures'); Target=(Join-Path $installRoot 'textures') },
    @{ Source=(Join-Path $repoRoot 'games\packerbase'); Target=(Join-Path $UserData 'games\packerbase') }
)) {
    foreach ($file in Get-ChildItem -LiteralPath $part.Source -Recurse -File -Force) {
        $relative = $file.FullName.Substring($part.Source.Length).TrimStart('\', '/')
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $part.Target $relative)).Hash) { throw "Deployment hash mismatch: $relative" }
    }
}
$config = Join-Path $UserData 'minetest.conf'
$expected = 'main_menu_script = ' + (Join-Path $installRoot 'mainmenu\init.lua')
$actual = @(Get-Content -LiteralPath $config | Where-Object { $_ -match '^main_menu_script\s*=' })
if ($actual.Count -ne 1 -or $actual[0] -cne $expected) { throw 'main_menu_script verification failed' }
Write-Host "Verified menu, textures, PackerMOD Base and configuration: $UserData"
Write-Host 'Protected Pack, world and cache hashes unchanged.'
