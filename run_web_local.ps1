$ErrorActionPreference = "Stop"

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    throw "Missing .env file. Copy .env.example to .env and fill in the real values."
}

Get-Content $envFile | ForEach-Object {
    if ($_ -match '^\s*#' -or $_ -match '^\s*$') { return }
    $parts = $_ -split '=', 2
    if ($parts.Length -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    [System.Environment]::SetEnvironmentVariable($name, $value, "Process")
}

if (-not $env:FIREBASE_WEB_API_KEY) { throw "FIREBASE_WEB_API_KEY is not set in .env" }
if (-not $env:TURN_SERVER_URL) { throw "TURN_SERVER_URL is not set in .env" }
if (-not $env:TURN_SERVER_USERNAME) { throw "TURN_SERVER_USERNAME is not set in .env" }
if (-not $env:TURN_SERVER_CREDENTIAL) { throw "TURN_SERVER_CREDENTIAL is not set in .env" }

Write-Host "Loaded local env from .env"

flutter run -d chrome `
  --dart-define=FIREBASE_WEB_API_KEY="$env:FIREBASE_WEB_API_KEY" `
  --dart-define=TURN_SERVER_URL="$env:TURN_SERVER_URL" `
  --dart-define=TURN_SERVER_URL_TCP="$env:TURN_SERVER_URL_TCP" `
  --dart-define=TURN_SERVER_USERNAME="$env:TURN_SERVER_USERNAME" `
  --dart-define=TURN_SERVER_CREDENTIAL="$env:TURN_SERVER_CREDENTIAL"
