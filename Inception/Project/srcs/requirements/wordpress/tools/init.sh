#!/bin/bash

set -e

DB_PASSWORD="$(cat /run/secrets/db_password)"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

mkdir -p /run/php
mkdir -p /var/www/html

if [ ! -f /var/www/html/wp-load.php ]; then
    echo "Copying WordPress files into persistent volume..."

    cp -a /usr/src/wordpress/. /var/www/html/
fi

chown -R www-data:www-data /var/www/html

echo "Waiting for MariaDB..."
TRY=1
MAX_TRIES=30

until mariadb-admin ping -h mariadb -u "${MYSQL_USER}" -p"${DB_PASSWORD}" --silent; do
    # If we've reached the maximum number of attempts, abort the container.
    if [ "$TRY" -ge "$MAX_TRIES" ]; then
        echo "ERROR: MariaDB did not become ready after $MAX_TRIES attempts."
        exit 1
    fi

    echo "MariaDB not ready yet... attempt $TRY/$MAX_TRIES"

    # Wait 2 seconds before trying again.
    sleep 2

    # Increment TRY by 1.
    TRY=$((TRY + 1))
done

echo "MariaDB is ready."

if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Creating wp-config.php..."

    wp config create \
        --allow-root \
        --path=/var/www/html \
        --dbname="${MYSQL_DATABASE}" \
        --dbuser="${MYSQL_USER}" \
        --dbpass="${DB_PASSWORD}" \
        --dbhost="mariadb:3306"
fi

if ! wp core is-installed \
    --allow-root \
    --path=/var/www/html
then
    echo "Installing WordPress..."

    wp core install \
        --allow-root \
        --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}" \
        --skip-email
fi

echo "Configuring the Redis object cache..."

wp config set WP_REDIS_HOST redis \
    --allow-root \
    --path=/var/www/html \
    --type=constant

wp config set WP_REDIS_PORT 6379 \
    --allow-root \
    --path=/var/www/html \
    --type=constant \
    --raw

wp config set WP_REDIS_DATABASE 0 \
    --allow-root \
    --path=/var/www/html \
    --type=constant \
    --raw

wp config set WP_REDIS_PREFIX "${DOMAIN_NAME}:" \
    --allow-root \
    --path=/var/www/html \
    --type=constant

if ! wp plugin is-installed redis-cache \
    --allow-root \
    --path=/var/www/html
then
    echo "Installing the Redis Object Cache plugin from the image..."
    cp -a /usr/src/wordpress/wp-content/plugins/redis-cache \
        /var/www/html/wp-content/plugins/
fi

wp plugin activate redis-cache \
    --allow-root \
    --path=/var/www/html

wp redis enable \
    --allow-root \
    --path=/var/www/html

if ! wp user get "${WP_USER}" \
    --allow-root \
    --path=/var/www/html \
    >/dev/null 2>&1
then
    echo "Creating second WordPress user..."

    wp user create \
        "${WP_USER}" \
        "${WP_USER_EMAIL}" \
        --allow-root \
        --path=/var/www/html \
        --user_pass="${WP_USER_PASSWORD}" \
        --role=author
fi

if ! wp theme is-installed vamika \
    --allow-root \
    --path=/var/www/html \
    >/dev/null 2>&1
then
    echo "Installing and activating Vamika theme..."

    wp theme install vamika \
        --activate \
        --allow-root \
        --path=/var/www/html
fi

chown -R www-data:www-data /var/www/html


exec "$@"
