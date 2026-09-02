#!/bin/sh

set -e

mkdir -p /app/data

# 1. Pre-configure SQLite database mode so setup-database step is automatic
if [ ! -f /app/data/db-config.json ]; then
    cat << 'EOF' > /app/data/db-config.json
{
    "type": "sqlite",
    "port": 3306,
    "hostname": "",
    "username": "",
    "password": "",
    "dbName": "kuma",
    "ssl": false,
    "ca": ""
}
EOF
fi

exec "$@"
