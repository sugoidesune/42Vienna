#!/bin/bash

set -e

# Create the runtime directory MariaDB uses for its Unix socket and PID file.
# -p means "parents": create the directory if needed, and do not error if it already exists.
mkdir -p /run/mysqld

# Change ownership of that directory recursively to the mysql user and mysql group.
# -R means recursive, though here the directory is tiny.
chown  mysql:mysql /run/mysqld

# Ensure the persistent database directory exists.
mkdir -p /var/lib/mysql

# Give MariaDB ownership of its database directory.
chown mysql:mysql /var/lib/mysql

MYSQL_PASSWORD="$(cat /run/secrets/db_password)"
MYSQL_ROOT_PASSWORD="$(cat /run/secrets/db_root_password)"

if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "Initializing MariaDB..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    mariadbd \
        --user=mysql \
        --bootstrap <<EOF
USE mysql;

FLUSH PRIVILEGES;

ALTER USER 'root'@'localhost'
IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
IDENTIFIED BY '${MYSQL_PASSWORD}';

CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost'
IDENTIFIED BY '${MYSQL_PASSWORD}';

GRANT ALL PRIVILEGES
ON \`${MYSQL_DATABASE}\`.*
TO '${MYSQL_USER}'@'%';

GRANT ALL PRIVILEGES
ON \`${MYSQL_DATABASE}\`.*
TO '${MYSQL_USER}'@'localhost';

DELETE FROM mysql.user WHERE User='';

FLUSH PRIVILEGES;
EOF
fi

exec "$@"
