[CmdletBinding()]
param(
    [Parameter(Mandatory)][uri]$Url,
    [string]$DownloadDirectory = (Join-Path $env:TEMP 'moyu-codex-install')
)
$ErrorActionPreference = 'Stop'
# The agent resolves this URL from the current official download page.
if ($Url.Scheme -ne 'https' -or $Url.Host -notmatch '(^|\.)(openai\.com|oaistatic\.com)$') {
    throw 'Expected an HTTPS OpenAI installer URL. Use the official Store UI for Store links.'
}
New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
$file = Join-Path $DownloadDirectory ('CodexSetup-' + [guid]::NewGuid().ToString('N') + '.exe')
Invoke-WebRequest -Uri $Url -OutFile $file -UseBasicParsing
$signature = Get-AuthenticodeSignature -LiteralPath $file
if ($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Subject -notmatch '(?i)\bOpenAI\b') {
    throw "Installer signature is not a valid OpenAI signature. Do not run: $file"
}
[pscustomobject]@{ Path = $file; SHA256 = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash; Signer = $signature.SignerCertificate.Subject }
