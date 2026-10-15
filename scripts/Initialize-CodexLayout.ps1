[CmdletBinding()]
param([string]$Root = 'D:\Codex')
$ErrorActionPreference = 'Stop'
if (-not [IO.Path]::IsPathRooted($Root) -or $Root.StartsWith('\\')) {
    throw 'Root must be an absolute local path.'
}
$Root = [IO.Path]::GetFullPath($Root)
foreach ($name in 'WorkSpace', 'Download', 'Memory', 'Profile') {
    $path = Join-Path $Root $name
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Get-Item -LiteralPath $path | Select-Object Name, FullName
}
