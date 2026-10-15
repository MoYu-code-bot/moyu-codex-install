[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Source,
    [Parameter(Mandatory)][string]$Destination
)
$ErrorActionPreference = 'Stop'
foreach ($path in $Source, $Destination) {
    if (-not [IO.Path]::IsPathRooted($path) -or $path.StartsWith('\\')) { throw 'Use absolute local paths.' }
}
$Source = [IO.Path]::GetFullPath($Source).TrimEnd('\')
$Destination = [IO.Path]::GetFullPath($Destination).TrimEnd('\')
if ($Source -eq [IO.Path]::GetPathRoot($Source).TrimEnd('\') -or
    $Destination -eq [IO.Path]::GetPathRoot($Destination).TrimEnd('\') -or
    $Source -eq $Destination -or $Destination.StartsWith($Source + '\', [StringComparison]::OrdinalIgnoreCase) -or
    $Source.StartsWith($Destination + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Paths must be separate directories, never drive roots.' }
$item = Get-Item -LiteralPath $Source -Force
if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Source must be a real directory; inspect existing redirects manually.' }
if (Test-Path -LiteralPath $Destination) { throw 'Destination exists; refusing to merge or overwrite.' }
$links = @(Get-ChildItem -LiteralPath $Source -Recurse -Force -Attributes ReparsePoint)
if ($links.Count) { throw 'Source contains links; inspect their real targets before migrating.' }
foreach ($path in $Source, (Split-Path -Parent $Destination)) {
    $parent = $path
    while ($parent) {
        if (Test-Path -LiteralPath $parent) {
            if ((Get-Item -LiteralPath $parent -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'A path ancestor is redirected; inspect it first.' }
        }
        $parent = Split-Path -Parent $parent
    }
}
New-Item -ItemType Directory -Path (Split-Path -Parent $Destination) -Force | Out-Null
Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
$files = @(Get-ChildItem -LiteralPath $Source -File -Recurse -Force)
foreach ($file in $files) {
    $copy = Join-Path $Destination $file.FullName.Substring($Source.Length + 1)
    if ((Get-FileHash -LiteralPath $file.FullName).Hash -ne (Get-FileHash -LiteralPath $copy).Hash) { throw "Copy verification failed: $copy. Source is unchanged." }
}
$backup = $Source + '.before-migration-' + [guid]::NewGuid().ToString('N')
Move-Item -LiteralPath $Source -Destination $backup
try {
    New-Item -ItemType Junction -Path $Source -Target $Destination | Out-Null
} catch {
    Move-Item -LiteralPath $backup -Destination $Source
    throw
}
[pscustomobject]@{ Source = $Source; Destination = $Destination; Backup = $backup; VerifiedFiles = $files.Count }
