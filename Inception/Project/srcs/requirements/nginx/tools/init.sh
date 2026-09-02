#!/bin/bash

set -e

mkdir -p /etc/nginx/ssl

# 1. Setup Root Certificate Authority (CA)
if [ -f /run/secrets/ca_crt ] && [ -f /run/secrets/ca_key ]; then
    echo "Using Root CA from secrets..."
    cp /run/secrets/ca_crt /etc/nginx/ssl/ca.crt
    cp /run/secrets/ca_key /etc/nginx/ssl/ca.key
elif [ ! -f /etc/nginx/ssl/ca.crt ] || [ ! -f /etc/nginx/ssl/ca.key ]; then
    echo "No Root CA secrets found. Generating new Local Root CA..."
    openssl req -x509 -nodes -newkey rsa:2048 -days 3650 \
        -keyout /etc/nginx/ssl/ca.key \
        -out /etc/nginx/ssl/ca.crt \
        -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=Inception/CN=InceptionRootCA"
fi

# 2. Generate Nginx Server Key and Certificate Signing Request
echo "Generating Server TLS Certificate signed by Root CA for ${DOMAIN_NAME}..."
openssl req -nodes -newkey rsa:2048 \
    -keyout /etc/nginx/ssl/inception.key \
    -out /etc/nginx/ssl/inception.csr \
    -subj "/C=AT/ST=Vienna/L=Vienna/O=42/OU=Inception/CN=${DOMAIN_NAME}"

# 3. Sign the Server Certificate using the Root CA with SAN extension
openssl x509 -req -days 365 \
    -in /etc/nginx/ssl/inception.csr \
    -CA /etc/nginx/ssl/ca.crt \
    -CAkey /etc/nginx/ssl/ca.key \
    -CAcreateserial \
    -out /etc/nginx/ssl/inception.crt \
    -extfile <(printf "subjectAltName=DNS:${DOMAIN_NAME},DNS:kuma.${DOMAIN_NAME},DNS:adminer.${DOMAIN_NAME}\nbasicConstraints=CA:FALSE\nkeyUsage=digitalSignature,keyEncipherment\nextendedKeyUsage=serverAuth")

rm -f /etc/nginx/ssl/inception.csr

sed \
    "s/__DOMAIN_NAME__/${DOMAIN_NAME}/g" \
    /etc/nginx/nginx.conf.template \
    > /etc/nginx/nginx.conf

nginx -t

exec "$@"
