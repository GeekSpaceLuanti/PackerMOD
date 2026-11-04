[CmdletBinding()]
param()
$ErrorActionPreference = "Stop"
$repoRoot = Split-Path -Parent $PSScriptRoot
if (Get-Process -Name luanti -ErrorAction SilentlyContinue) {
    throw "Luanti is running. Close it normally before deploying."
}
$userDir = Join-Path $env:APPDATA "Luanti"
if (-not (Test-Path -LiteralPath $userDir)) { $userDir = Join-Path $env:APPDATA "Minetest" }
if (-not (Test-Path -LiteralPath $userDir)) { throw "Luanti user data not found" }
$userDir = [IO.Path]::GetFullPath($userDir)
$installRoot = [IO.Path]::GetFullPath((Join-Path $userDir 'PackerMOD'))
if ((Test-Path -LiteralPath $installRoot) -and ((Get-Item -LiteralPath $installRoot).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    throw "Installation root is a link; inspect it before deployment"
}
# Validate the exact replacement targets before the installer removes anything.
foreach ($leaf in @('mainmenu', 'textures')) {
    $target = [IO.Path]::GetFullPath((Join-Path $installRoot $leaf))
    if (-not $target.StartsWith($installRoot + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Invalid deployment target"
    }
    if (Test-Path -LiteralPath $target) {
        $item = Get-Item -LiteralPath $target
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Deployment target is a link; inspect it before replacing"
        }
    }
}
$protectedRoots = @((Join-Path $installRoot 'packs'), (Join-Path $installRoot 'cache'), (Join-Path $userDir 'worlds'))
function Get-ProtectedState {
    @($protectedRoots | ForEach-Object {
        if (Test-Path -LiteralPath $_) {
            Get-ChildItem -LiteralPath $_ -Recurse -Force -File |
                Select-Object FullName, Length, LastWriteTimeUtc
        }
    } | Sort-Object FullName) | ConvertTo-Json -Depth 3 -Compress
}
$before = Get-ProtectedState
$backup = Join-Path $installRoot ('install-backups\' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup -Force | Out-Null
foreach ($leaf in @('mainmenu', 'textures')) {
    $path = Join-Path $installRoot $leaf
    if (Test-Path -LiteralPath $path) { Copy-Item -LiteralPath $path -Destination (Join-Path $backup $leaf) -Recurse }
}
$config = Join-Path $userDir 'minetest.conf'
if (Test-Path -LiteralPath $config) { Copy-Item -LiteralPath $config -Destination (Join-Path $backup 'minetest.conf') }
& (Join-Path $repoRoot 'install\install.ps1') -Mode copy
if ((Get-ProtectedState) -cne $before) { throw "Protected data changed during deployment" }
foreach ($leaf in @('mainmenu', 'textures')) {
    $source = Join-Path $repoRoot $leaf
    Get-ChildItem -LiteralPath $source -Recurse -File | ForEach-Object {
        $relative = $_.FullName.Substring($source.Length).TrimStart('\')
        $target = Join-Path (Join-Path $installRoot $leaf) $relative
        if ((Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
            throw "Deployment hash mismatch: $relative"
        }
    }
}
Write-Host "Verified deployment. Protected data unchanged. Backup: $backup"
