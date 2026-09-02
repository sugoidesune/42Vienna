#!/bin/sh

set -eu

: "${FTP_USER:?FTP_USER is required}"
: "${DOMAIN_NAME:?DOMAIN_NAME is required}"

password_file=/run/secrets/ftp_password

if [ ! -s "$password_file" ]; then
    echo "FTP password secret is missing or empty" >&2
    exit 1
fi

case "$FTP_USER" in
    *[!A-Za-z0-9_-]*|'')
        echo "FTP_USER contains unsupported characters" >&2
        exit 1
        ;;
esac

# Ensure www-data group exists with GID 33 matching WordPress volume
if getent group www-data >/dev/null; then
    groupmod -g 33 www-data 2>/dev/null || true
else
    addgroup -g 33 -S www-data
fi

if ! getent passwd "$FTP_USER" >/dev/null; then
    useradd \
        --home-dir /var/www/html \
        --no-create-home \
        --shell /bin/sh \
        --groups www-data \
        "$FTP_USER"
fi

printf '%s:%s\n' "$FTP_USER" "$(cat "$password_file")" | chpasswd

# Preserve WordPress ownership while allowing the FTP user's www-data group to
# create and modify content. Existing directories need group-write permission;
# the umask in vsftpd.conf gives new files compatible permissions.
chgrp -R www-data /var/www/html
find /var/www/html -type d -exec chmod g+rwx {} +
find /var/www/html -type f -exec chmod g+rw {} +

pasv_addr="${FTP_PASV_ADDRESS:-$DOMAIN_NAME}"
if ! getent hosts "$pasv_addr" >/dev/null 2>&1; then
    echo "127.0.0.1 $pasv_addr" >> /etc/hosts || true
fi

sed "s/__PASV_ADDRESS__/$pasv_addr/g" \
    /etc/vsftpd.conf.template > /etc/vsftpd.conf

exec "$@"
