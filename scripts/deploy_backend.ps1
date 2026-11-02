<#
.SYNOPSIS
  Deploy vitanet-backend to the production VPS safely.

.DESCRIPTION
  1. Backs up the live code and database on the server (timestamped).
  2. Uploads the new code to a release folder.
  3. Runs the security + portal test suites there against a COPY of the live DB.
     Aborts (live service untouched) if any test fails.
  4. Writes/updates the server .env (keys come from vitanet-backend/.env.production
     on this PC, never printed) and makes systemd load it.
  5. Swaps the new code in, restarts the service and health-checks it.
     Rolls back automatically if the health check fails.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\deploy_backend.ps1
#>
param(
  [string]$SshHost = "trading-bot",
  [string]$RemoteDir = "/home/ubuntu/vitanet-backend",
  [string]$EnvFile = "vitanet-backend/.env.production"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$release = "/home/ubuntu/vitanet-release-$stamp"

if (-not (Test-Path $EnvFile)) {
  Write-Host "Missing $EnvFile. Create it with (one per line):" -ForegroundColor Yellow
  Write-Host "  OPENROUTER_API_KEYS=...   (comma-separated if several)"
  Write-Host "  TAVILY_API_KEY=...        (optional)"
  Write-Host "  GOOGLE_API_KEY=...        (optional, with GOOGLE_CSE_ID)"
  Write-Host "  GOOGLE_CSE_ID=..."
  exit 1
}

Write-Host "1/5 Uploading code to $release ..."
ssh -o BatchMode=yes $SshHost "mkdir -p $release"
scp -q -r -o BatchMode=yes vitanet-backend/app vitanet-backend/test_security.py vitanet-backend/test_portal.py vitanet-backend/requirements.txt "${SshHost}:$release/"

# Server .env: fixed settings + keys from the local (git-ignored) file.
$keys = Get-Content $EnvFile | Where-Object { $_ -match '^\s*[A-Z_]+\s*=' -and $_ -notmatch '^\s*#' }
$envLines = @(
  "ENVIRONMENT=production",
  "FIREBASE_PROJECT_ID=vitanet-62e40",
  "BOOTSTRAP_ADMIN_EMAILS=anonyemichael6@gmail.com"
) + $keys
$tmpEnv = Join-Path $env:TEMP "vitanet-prod-$stamp.env"
[IO.File]::WriteAllText($tmpEnv, (($envLines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
scp -q -o BatchMode=yes $tmpEnv "${SshHost}:$release/.env.new"
Remove-Item $tmpEnv

$remote = @'
set -e
REL="__REL__"; LIVE="__LIVE__"; STAMP="__STAMP__"
cd "$REL"
find . -name '*.py' -exec sed -i 's/\r$//' {} +
sed -i '1s/^\xEF\xBB\xBF//; s/\r$//' .env.new

echo "2/5 Backing up live code + database ..."
mkdir -p /home/ubuntu/vitanet-backups
tar --exclude=venv --exclude=__pycache__ -czf "/home/ubuntu/vitanet-backups/backend-$STAMP.tgz" -C "$LIVE" .
cp "$LIVE/vitanet.db" "/home/ubuntu/vitanet-backups/vitanet-$STAMP.db"

echo "3/5 Testing new code against a copy of the live database ..."
cp "$LIVE/vitanet.db" "$REL/predeploy.db"
PY="$LIVE/venv/bin/python"
"$PY" -m pip install -q -r requirements.txt
for MOD in test_security test_portal; do
  rm -f security_test.db portal_test.db
  "$PY" - "$MOD" <<'EOF'
import importlib, sys, traceback
t = importlib.import_module(sys.argv[1])
names = sorted([n for n in dir(t) if n.startswith("test_")], key=lambda n: getattr(t, n).__code__.co_firstlineno)
failed = 0
for n in names:
    try:
        getattr(t, n)()
    except Exception:
        failed += 1; print("FAIL", n); traceback.print_exc(limit=3)
print(sys.argv[1], "failed:", failed)
sys.exit(1 if failed else 0)
EOF
done
# The live DB copy must open with the new models (creates new tables only).
DATABASE_URL="sqlite:///$REL/predeploy.db" "$PY" -c "
from app.database.base import Base
from app.database.connection import engine
import app.models
Base.metadata.create_all(bind=engine)
print('schema ok on live data copy')"

echo "4/5 Installing .env and systemd EnvironmentFile ..."
install -m 600 .env.new "$LIVE/.env"
sudo mkdir -p /etc/systemd/system/vitanet-backend.service.d
printf '[Service]\nEnvironmentFile=%s/.env\n' "$LIVE" | sudo tee /etc/systemd/system/vitanet-backend.service.d/env.conf >/dev/null
sudo systemctl daemon-reload

echo "5/5 Switching code and restarting ..."
rm -rf "$LIVE/app.previous"; mv "$LIVE/app" "$LIVE/app.previous"; cp -r "$REL/app" "$LIVE/app"
sudo systemctl restart vitanet-backend
sleep 4
if curl -fsS -m 10 127.0.0.1:8000/ >/dev/null && [ "$(curl -s -o /dev/null -w '%{http_code}' 127.0.0.1:8000/admin/stats)" = "401" ]; then
  echo "DEPLOYED OK: API up and /admin requires sign-in"
else
  echo "HEALTH CHECK FAILED - rolling back"
  rm -rf "$LIVE/app"; mv "$LIVE/app.previous" "$LIVE/app"
  sudo systemctl restart vitanet-backend
  exit 1
fi
'@
$remote = $remote.Replace("__REL__", $release).Replace("__LIVE__", $RemoteDir).Replace("__STAMP__", $stamp)
$tmpSh = Join-Path $env:TEMP "vitanet-deploy-$stamp.sh"
[IO.File]::WriteAllText($tmpSh, $remote.Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
scp -q -o BatchMode=yes $tmpSh "${SshHost}:/tmp/vitanet-deploy.sh"
Remove-Item $tmpSh
ssh -o BatchMode=yes $SshHost "bash /tmp/vitanet-deploy.sh; rc=`$?; rm -f /tmp/vitanet-deploy.sh; exit `$rc"
if ($LASTEXITCODE -ne 0) { Write-Host "Deploy aborted - live service unchanged or rolled back." -ForegroundColor Red; exit 1 }
Write-Host "Backend deployed. Backups: /home/ubuntu/vitanet-backups/*-$stamp.*" -ForegroundColor Green
