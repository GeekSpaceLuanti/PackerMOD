[CmdletBinding()]
param(
    [ValidateSet('copy', 'symlink')]
    [string]$Mode = 'copy',
    [string]$UserData
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $UserData) {
    $UserData = Join-Path $env:APPDATA 'Luanti'
    if (-not (Test-Path -LiteralPath $UserData)) { $UserData = Join-Path $env:APPDATA 'Minetest' }
}
if (-not (Test-Path -LiteralPath $UserData -PathType Container)) { throw 'Luanti user data directory not found. Run Luanti once or pass -UserData.' }
$UserData = [IO.Path]::GetFullPath($UserData).TrimEnd('\', '/')
$targetRoot = Join-Path $UserData 'PackerMOD'
$gameSource = Join-Path $repoRoot 'games\packerbase'
if (-not (Test-Path -LiteralPath (Join-Path $gameSource 'game.conf'))) { throw 'Bundled games/packerbase/game.conf is missing' }

# Never follow directory links while backing up or replacing an installation.
function Assert-PlainTree([string]$Path) {
    if (Test-Path -LiteralPath $Path) {
        $items = @((Get-Item -LiteralPath $Path -Force))
        if ($items[0].PSIsContainer -and -not ($items[0].Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            $items += @(Get-ChildItem -LiteralPath $Path -Force -Recurse)
        }
        if ($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }) {
            throw "Installation path contains a link; inspect it before replacing: $Path"
        }
    }
}
foreach ($ancestor in @($UserData, $targetRoot, (Join-Path $UserData 'games'))) {
    if ((Test-Path -LiteralPath $ancestor) -and ((Get-Item -LiteralPath $ancestor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "Installation parent is a link: $ancestor" }
}
$components = @(
    @{ Source = (Join-Path $repoRoot 'mainmenu'); Target = (Join-Path $targetRoot 'mainmenu'); Name = 'mainmenu' },
    @{ Source = (Join-Path $repoRoot 'textures'); Target = (Join-Path $targetRoot 'textures'); Name = 'textures' },
    @{ Source = $gameSource; Target = (Join-Path $UserData 'games\packerbase'); Name = 'packerbase' }
)
foreach ($part in $components) {
    $resolved = [IO.Path]::GetFullPath($part.Target)
    if (-not $resolved.StartsWith($UserData + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Target escapes user data directory' }
    Assert-PlainTree $part.Source
    $part.Linked = $false
    if (Test-Path -LiteralPath $part.Target) {
        $item = Get-Item -LiteralPath $part.Target -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            $linkTarget = @($item.Target)[0]
            if ($linkTarget -and -not [IO.Path]::IsPathRooted($linkTarget)) { $linkTarget = Join-Path (Split-Path -Parent $part.Target) $linkTarget }
            if ($part.Name -eq 'packerbase' -or $item.LinkType -ne 'SymbolicLink' -or -not $linkTarget -or [IO.Path]::GetFullPath($linkTarget) -ine $part.Source) { throw "Unrecognized installation link: $($part.Target)" }
            $part.Linked = $true
        } else { Assert-PlainTree $part.Target }
    }
}
$gameTarget = Join-Path $UserData 'games\packerbase'
if (Test-Path -LiteralPath $gameTarget) {
    if (-not (Test-Path -LiteralPath (Join-Path $gameTarget '.packermod-managed'))) { throw 'Existing packerbase is not managed by PackerMOD; refusing to overwrite it' }
    if (Get-ChildItem -LiteralPath $gameTarget -Recurse -Force -File | Where-Object { $_.Name -in @('world.mt', 'map.sqlite', 'map_meta.txt', 'players.sqlite', 'auth.sqlite') }) {
        throw 'World data found inside the game directory; refusing to replace it'
    }
}
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backup = Join-Path $targetRoot "install-backups\$stamp"
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$conf = Join-Path $UserData 'minetest.conf'
if (Test-Path -LiteralPath $conf) { Copy-Item -LiteralPath $conf -Destination (Join-Path $backup 'minetest.conf') }
foreach ($part in $components) {
    if (Test-Path -LiteralPath $part.Target) { Copy-Item -LiteralPath $part.Target -Destination (Join-Path $backup $part.Name) -Recurse }
}
foreach ($leaf in @('packs', 'cache')) { New-Item -ItemType Directory -Path (Join-Path $targetRoot $leaf) -Force | Out-Null }
New-Item -ItemType Directory -Path (Join-Path $UserData 'games') -Force | Out-Null
foreach ($part in $components) {
    $stage = $part.Target + '.installing-' + $stamp
    if (Test-Path -LiteralPath $stage) { throw "Staging path already exists: $stage" }
    # Copy and verify the complete tree before replacing a backed-up destination.
    Copy-Item -LiteralPath $part.Source -Destination $stage -Recurse
    foreach ($file in Get-ChildItem -LiteralPath $part.Source -Recurse -File -Force) {
        $relative = $file.FullName.Substring($part.Source.Length).TrimStart('\', '/')
        if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath (Join-Path $stage $relative)).Hash) { throw "Staged hash mismatch: $relative" }
    }
    if (Test-Path -LiteralPath $part.Target) {
        if ($part.Linked) { Remove-Item -LiteralPath $part.Target -Force }
        else { Remove-Item -LiteralPath $part.Target -Recurse -Force }
    }
    # Game copies remain independent from a checkout and carry an ownership marker.
    if ($Mode -eq 'symlink' -and $part.Name -ne 'packerbase') {
        try {
            New-Item -ItemType SymbolicLink -Path $part.Target -Target $part.Source -ErrorAction Stop | Out-Null
            Remove-Item -LiteralPath $stage -Recurse -Force
        } catch {
            Write-Warning 'Symlink unavailable; using verified copy.'
            Move-Item -LiteralPath $stage -Destination $part.Target
        }
    } else { Move-Item -LiteralPath $stage -Destination $part.Target }
    Write-Host "Installed $($part.Name): $($part.Target)"
}
Set-Content -LiteralPath (Join-Path $gameTarget '.packermod-managed') -Value 'Installed by PackerMOD; previous versions are in PackerMOD/install-backups.' -Encoding utf8

# Preserve distribution licenses separately from user-maintained Pack data.
$licenseRoot = Join-Path $targetRoot 'licenses'
New-Item -ItemType Directory -Path $licenseRoot -Force | Out-Null
Get-ChildItem -LiteralPath $repoRoot -File | Where-Object { $_.Name -match '^(LICENSE|COPYING|NOTICE|THIRD_PARTY)' } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $licenseRoot $_.Name) -Force
}
Copy-Item -LiteralPath (Join-Path $repoRoot 'vendor\pixelarticons\LICENSE') -Destination (Join-Path $licenseRoot 'pixelarticons-MIT.txt') -Force
$content = if (Test-Path -LiteralPath $conf) { [IO.File]::ReadAllText($conf) } else { '' }
if ($content -match '(?m)^main_menu_script\s*=') {
    if ($content -notmatch '(?m)^# packermod-backup main_menu_script') { $content = $content -replace '(?m)^main_menu_script\s*=', '# packermod-backup main_menu_script =' }
    $content = $content -replace '(?m)^main_menu_script\s*=.*\r?\n?', ''
}
if ($content -and -not $content.EndsWith("`n")) { $content += "`n" }
$content += 'main_menu_script = ' + (Join-Path $targetRoot 'mainmenu\init.lua') + "`n"
[IO.File]::WriteAllText($conf, $content, [Text.UTF8Encoding]::new($false))
Write-Host "Using Luanti user data: $UserData"
Write-Host "Backup: $backup"
Write-Host 'Done. Start Luanti and select PackerMOD Base when creating a Pack.'
