$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('codex-skill-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
& "$PSScriptRoot/Initialize-CodexLayout.ps1" -Root $testRoot | Out-Null
& "$PSScriptRoot/Initialize-CodexLayout.ps1" -Root $testRoot | Out-Null
foreach ($name in 'WorkSpace', 'Download', 'Memory', 'Profile') {
    if (-not (Test-Path -LiteralPath (Join-Path $testRoot $name) -PathType Container)) { throw "Missing $name" }
}
$source = Join-Path $testRoot 'source & sample'
New-Item -ItemType Directory -Path (Join-Path $source 'empty') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $source '.sample') -Value 'preserve me'
$destination = Join-Path $testRoot 'Profile/sample'
$result = & "$PSScriptRoot/Move-CodexDirectory.ps1" -Source $source -Destination $destination
if ((Get-Content -LiteralPath (Join-Path $source '.sample')) -ne 'preserve me') { throw 'Link cannot read migrated data.' }
if (-not (Test-Path -LiteralPath (Join-Path $destination 'empty'))) { throw 'Empty directory lost.' }
if (-not (Test-Path -LiteralPath (Join-Path $result.Backup '.sample'))) { throw 'Backup missing.' }
$rejected = $false
try { & "$PSScriptRoot/Move-CodexDirectory.ps1" -Source $result.Backup -Destination $destination } catch { $rejected = $true }
if (-not $rejected) { throw 'Existing destination was not rejected.' }
$rejected = $false
try { & "$PSScriptRoot/Get-CodexInstaller.ps1" -Url 'https://example.com/installer.exe' } catch { $rejected = $true }
if (-not $rejected) { throw 'Untrusted download URL was accepted.' }
[IO.Directory]::Delete($source, $false)
Move-Item -LiteralPath $result.Backup -Destination $source
if ((Get-Content -LiteralPath (Join-Path $source '.sample')) -ne 'preserve me') { throw 'Rollback failed.' }
Write-Output "PASS: layout, repeat creation, migration, backup, conflict refusal, URL rejection, rollback. Artifacts: $testRoot"
