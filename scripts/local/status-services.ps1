# Shows whether local PostgreSQL (5433) and Redis (6379) are up.
$PG    = "C:\PostgreSQL\16"
$REDIS = "C:\Redis\Redis-8.10.1-Windows-x64-msys2"
& "$PG\bin\pg_ctl.exe" -D "$PG\data" status
Write-Host "[redis] " (& "$REDIS\redis-cli.exe" -p 6379 ping 2>&1)
