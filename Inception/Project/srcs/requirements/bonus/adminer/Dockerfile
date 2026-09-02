FROM alpine:3.23

ARG ADMINER_VERSION=6.0.1

RUN apk add --no-cache \
        ca-certificates \
        php84 \
        php84-mysqli \
        php84-session \
    && apk add --no-cache --virtual .adminer-download curl \
    && adduser -D -H -s /sbin/nologin adminer \
    && install -d -o adminer -g adminer /var/www/adminer \
    && curl --fail --silent --show-error --location \
        "https://github.com/vrana/adminer/releases/download/v${ADMINER_VERSION}/adminer-${ADMINER_VERSION}-mysql-en.php" \
        --output /var/www/adminer/index.php \
    && chown adminer:adminer /var/www/adminer/index.php \
    && apk del .adminer-download

WORKDIR /var/www/adminer

USER adminer

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD wget -q -O /dev/null http://127.0.0.1:8080/ || exit 1

CMD ["php84", "-S", "0.0.0.0:8080", "-t", "/var/www/adminer"]
