[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$Version = '0.1.0',
    [string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $repoRoot 'dist' }
$OutputDirectory = [IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
foreach ($required in @('LICENSE.txt','COPYING','COPYING.LESSER','THIRD_PARTY_NOTICES.md','games\packerbase\game.conf','examples\packerbase\manifest.yaml')) {
    if (-not (Test-Path -LiteralPath (Join-Path $repoRoot $required) -PathType Leaf)) { throw "Release input missing: $required" }
}
# Packages contain complete source and media. Luanti binaries are not bundled.
# Sorting and a fixed ZIP entry timestamp make identical inputs reproducible.
function Write-SourceZip([string]$Root, [string[]]$Includes, [string]$Destination, [string[]]$ExtraFiles = @(), [Collections.IDictionary]$GeneratedFiles = @{}) {
    if (Test-Path -LiteralPath $Destination) { throw "Release already exists; choose a new version or output directory: $Destination" }
    $files = @($Includes | ForEach-Object {
        $path = Join-Path $Root $_
        if (Test-Path -LiteralPath $path -PathType Container) { Get-ChildItem -LiteralPath $path -Recurse -File -Force }
        else { Get-Item -LiteralPath $path -Force }
    } | Sort-Object FullName -Unique)
    $files += @($ExtraFiles | ForEach-Object { Get-Item -LiteralPath $_ })
    $files = @($files | Sort-Object FullName -Unique)
    $hashLines = [Collections.Generic.List[string]]::new()
    $stream = [IO.File]::Open($Destination, [IO.FileMode]::CreateNew)
    $archive = [IO.Compression.ZipArchive]::new($stream, [IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($file in $files) {
            $relative = if ($file.FullName.StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { $file.FullName.Substring($Root.Length).TrimStart('\','/').Replace('\','/') } else { $file.Name }
            $hashLines.Add((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + $relative)
            $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
            $inputStream = [IO.File]::OpenRead($file.FullName)
            $entryStream = $entry.Open()
            try { $inputStream.CopyTo($entryStream) } finally { $entryStream.Dispose(); $inputStream.Dispose() }
        }
        foreach ($name in @($GeneratedFiles.Keys | Sort-Object)) {
            $bytes = [Text.UTF8Encoding]::new($false).GetBytes([string]$GeneratedFiles[$name])
            $sha = [Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant() } finally { $sha.Dispose() }
            $hashLines.Add($hash + '  ' + $name)
            $entry = $archive.CreateEntry($name, [IO.Compression.CompressionLevel]::Optimal)
            $entry.LastWriteTime = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
            $entryStream = $entry.Open()
            try { $entryStream.Write($bytes, 0, $bytes.Length) } finally { $entryStream.Dispose() }
        }
        $entry = $archive.CreateEntry('SHA256SUMS', [IO.Compression.CompressionLevel]::Optimal)
        $entry.LastWriteTime = [DateTimeOffset]::new(2000,1,1,0,0,0,[TimeSpan]::Zero)
        $writer = [IO.StreamWriter]::new($entry.Open(), [Text.UTF8Encoding]::new($false))
        try { $writer.Write(($hashLines -join "`n") + "`n") } finally { $writer.Dispose() }
    } finally { $archive.Dispose(); $stream.Dispose() }
    Write-Host "Created $Destination ($($files.Count + $GeneratedFiles.Count) files)"
}
$sourceZip = Join-Path $OutputDirectory "PackerMOD-$Version-source.zip"
$starterZip = Join-Path $OutputDirectory "PackerMOD-$Version-starter.zip"
$sourceInputs = @('mainmenu','textures','games','install','scripts','spec','test_fixtures','vendor','docs','examples','README.md','Makefile','LICENSE.txt','COPYING','COPYING.LESSER','THIRD_PARTY_NOTICES.md')
$sourceRevision = "git_head = unavailable`ngit_dirty = unavailable`n"
try {
if (Get-Command git -ErrorAction SilentlyContinue) {
    # A source archive extracted inside another repository must not inherit that
    # unrelated repository's revision. Only this exact checkout supplies provenance.
    $gitRoot = & git -C $repoRoot rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $gitRoot -and [IO.Path]::GetFullPath($gitRoot) -ieq [IO.Path]::GetFullPath($repoRoot)) {
        $head = & git -C $repoRoot rev-parse --verify HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and $head -match '^[0-9a-f]{40,64}$') {
            $status = @(& git -C $repoRoot status --porcelain --untracked-files=normal 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $dirty = if ($status.Count -gt 0) { 'true' } else { 'false' }
                $sourceRevision = "git_head = $head`ngit_dirty = $dirty`n"
            }
        }
    }
}
} catch {
    # Git may be absent, unavailable, or forbidden by safe.directory policy.
    $sourceRevision = "git_head = unavailable`ngit_dirty = unavailable`n"
}
Write-SourceZip -Root $repoRoot -Includes $sourceInputs -Destination $sourceZip -GeneratedFiles @{ 'SOURCE_REVISION.txt' = $sourceRevision }
$starterLicenses = @('LICENSE.txt','COPYING','COPYING.LESSER') | ForEach-Object { Join-Path $repoRoot $_ }
Write-SourceZip (Join-Path $repoRoot 'examples\packerbase') @('manifest.yaml','bundled_mods') $starterZip $starterLicenses
$sumLines = @($sourceZip,$starterZip) | ForEach-Object { (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant() + '  ' + [IO.Path]::GetFileName($_) }
[IO.File]::WriteAllText((Join-Path $OutputDirectory 'SHA256SUMS'), ($sumLines -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Host 'Source distribution only: install a compatible Luanti engine separately. Starter ZIP imports through PackerMOD.'
