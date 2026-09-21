# Starts the local (non-Docker) PostgreSQL 16 + PostGIS and Redis 8 used by the backend in development.
# PostgreSQL: C:\PostgreSQL\16  (port 5433, user postgres, password from rideshare-backend/.env)
# Redis:      C:\Redis          (port 6379, no password)
$ErrorActionPreference = "Continue"
$PG    = "C:\PostgreSQL\16"
$REDIS = "C:\Redis\Redis-8.10.1-Windows-x64-msys2"

# --- PostgreSQL ---
$status = & "$PG\bin\pg_ctl.exe" -D "$PG\data" status 2>&1
if ($LASTEXITCODE -eq 0) {
  Write-Host "[postgres] already running on port 5433"
} else {
  & "$PG\bin\pg_ctl.exe" -D "$PG\data" -l "$PG\logs\postgres.log" -w start
}

# --- Redis ---
$pong = & "$REDIS\redis-cli.exe" -p 6379 ping 2>$null
if ($pong -eq "PONG") {
  Write-Host "[redis] already running on port 6379"
} else {
  Start-Process -FilePath "$REDIS\redis-server.exe" -ArgumentList "/Redis/redis.local.conf" -WorkingDirectory $REDIS -WindowStyle Hidden
  Start-Sleep -Seconds 2
  Write-Host "[redis] " (& "$REDIS\redis-cli.exe" -p 6379 ping)
}
