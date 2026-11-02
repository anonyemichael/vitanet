<#
.SYNOPSIS
  Publish the backend's current public URL to Firestore app_config/backend,
  which every installed VitaNet app reads at startup.

.DESCRIPTION
  Reads the live Cloudflare quick-tunnel hostname from the VPS (or takes -Url),
  then writes it with your logged-in Firebase CLI account. Run it whenever the
  tunnel restarts and gets a new address.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\set_backend_url.ps1
  powershell -ExecutionPolicy Bypass -File scripts\set_backend_url.ps1 -Url https://api.example.com
#>
param(
  [string]$Url,
  [string]$SshHost = "trading-bot",
  [string]$Project = "vitanet-62e40"
)
$ErrorActionPreference = "Stop"

if (-not $Url) {
  $json = ssh -o BatchMode=yes $SshHost "curl -s -m 5 127.0.0.1:20241/quicktunnel"
  $hostName = ($json | ConvertFrom-Json).hostname
  if (-not $hostName) { throw "Could not read the tunnel hostname from the server." }
  $Url = "https://$hostName/"
}
if ($Url -notmatch '^https://') { throw "URL must start with https://" }
if (-not $Url.EndsWith('/')) { $Url = "$Url/" }

# Check the backend answers there before publishing it.
$root = Invoke-RestMethod -TimeoutSec 15 $Url
if ($root.message -ne "VitaNet API running") { throw "That URL doesn't look like the VitaNet API." }

# Use the Firebase CLI's OAuth token (refresh it by running any firebase command first).
firebase projects:list | Out-Null
$cfg = Get-Content "$env:USERPROFILE\.config\configstore\firebase-tools.json" -Raw | ConvertFrom-Json
$token = $cfg.tokens.access_token
$body = @{ fields = @{
  url = @{ stringValue = $Url }
  updated_at = @{ timestampValue = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
} } | ConvertTo-Json -Depth 5
$doc = "https://firestore.googleapis.com/v1/projects/$Project/databases/(default)/documents/app_config/backend"
Invoke-RestMethod -Method Patch -Headers @{ Authorization = "Bearer $token" } -ContentType "application/json" -Body $body $doc | Out-Null
Write-Host "app_config/backend.url = $Url" -ForegroundColor Green
