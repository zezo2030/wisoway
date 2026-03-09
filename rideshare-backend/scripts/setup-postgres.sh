#!/bin/bash
# إعداد PostgreSQL للاتصال من التطبيق
# شغّل: sudo bash scripts/setup-postgres.sh

set -e

sudo -u postgres psql << 'EOF'
ALTER USER postgres PASSWORD 'postgres';
EOF

sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='rideshare'" | grep -q 1 || sudo -u postgres createdb rideshare
sudo -u postgres psql -d rideshare -c "CREATE EXTENSION IF NOT EXISTS postgis;" 2>/dev/null || true

echo "تم إعداد PostgreSQL بنجاح."
echo "يمكنك الآن تشغيل: npm run start:dev"
