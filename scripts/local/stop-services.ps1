# Stops the local (non-Docker) PostgreSQL and Redis started by start-services.ps1.
$PG    = "C:\PostgreSQL\16"
$REDIS = "C:\Redis\Redis-8.10.1-Windows-x64-msys2"
& "$REDIS\redis-cli.exe" -p 6379 shutdown 2>$null
Write-Host "[redis] stopped"
& "$PG\bin\pg_ctl.exe" -D "$PG\data" -m fast stop
