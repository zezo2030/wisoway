#!/usr/bin/env bash
# Deploy vision-way.tech from origin/main. Run ON THE SERVER (76.13.55.4):
#   ssh root@76.13.55.4 'bash -s' < scripts/deploy-prod.sh   # (no compose exec inside, so stdin is safe)
# or copy the file over and run: bash /opt/wisoway/scripts/deploy-prod.sh
set -euo pipefail
cd /opt/wisoway

TS=$(date +%Y%m%d-%H%M%S)
BK=/root/backups/$TS
mkdir -p "$BK"
echo "== backup -> $BK"
docker compose exec -T postgres pg_dump -U postgres rideshare </dev/null | gzip > "$BK/rideshare.sql.gz"
tar czf "$BK/opt-wisoway.tgz" --exclude=node_modules --exclude=dist -C /opt wisoway
for img in rideshare-backend rideshare-dashboard; do docker tag "$img:latest" "$img:pre-$TS" || true; done
echo "$BK" > /root/backups/LAST

echo "== checkout origin/main"
git fetch origin
git checkout -f -B main origin/main
git log --oneline -1

echo "== nginx config test"
docker compose run --rm --no-deps -T nginx nginx -t </dev/null

echo "== build backend + dashboard (log: /root/build-$TS.log)"
nohup docker compose build backend dashboard > "/root/build-$TS.log" 2>&1
tail -3 "/root/build-$TS.log"

echo "== up"
docker compose up -d backend dashboard
docker compose up -d --force-recreate --no-deps nginx

echo "== wait for backend (migrations run on start)"
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1/api/v1/health >/dev/null 2>&1; then echo "backend healthy"; break; fi
  sleep 5
done
docker compose ps
docker compose logs --tail=20 backend | grep -iE "migration|error|started" || true
