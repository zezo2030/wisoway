#!/bin/sh
# Rideshare Backend - container entrypoint
#
# The production image is pruned of devDependencies, so the `db:migration:run`
# npm script (ts-node based) is not available here. Migrations are instead run
# against the compiled data source with the typeorm CLI, which ships as a
# production dependency. Config comes from the environment, not dotenv.
#
# Set RUN_MIGRATIONS=false to skip this and start the app directly.
set -e

DATA_SOURCE="dist/src/database/data-source.js"

if [ "${RUN_MIGRATIONS:-true}" = "true" ]; then
  echo "[entrypoint] Waiting for postgres at ${POSTGRES_HOST:-localhost}:${POSTGRES_PORT:-5432} ..."
  i=0
  until node -e "
    const { Client } = require('pg');
    const c = new Client({
      host: process.env.POSTGRES_HOST || 'localhost',
      port: Number(process.env.POSTGRES_PORT || 5432),
      user: process.env.POSTGRES_USER || 'postgres',
      password: process.env.POSTGRES_PASSWORD || 'postgres',
      database: process.env.POSTGRES_DB || 'rideshare',
      ssl: process.env.POSTGRES_SSL === 'true' ? { rejectUnauthorized: false } : false,
    });
    c.connect().then(() => c.end()).catch(() => process.exit(1));
  " 2>/dev/null; do
    i=$((i + 1))
    if [ "$i" -ge 60 ]; then
      echo "[entrypoint] Postgres did not become reachable in time; aborting." >&2
      exit 1
    fi
    sleep 2
  done
  echo "[entrypoint] Postgres is reachable."

  echo "[entrypoint] Running migrations ..."
  node node_modules/typeorm/cli.js -d "$DATA_SOURCE" migration:run
  echo "[entrypoint] Migrations complete."
else
  echo "[entrypoint] RUN_MIGRATIONS=false - skipping migrations."
fi

exec "$@"
