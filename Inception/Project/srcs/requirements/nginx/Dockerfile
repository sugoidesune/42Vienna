FROM alpine:3.23

RUN apk add --no-cache \
    nginx \
    openssl \
    bash \
    sed \
    procps \
    net-tools \
    curl \
    && adduser -u 82 -D -S -G www-data www-data 2>/dev/null || true \
    && mkdir -p /run/nginx /etc/nginx/ssl /var/www/html

COPY conf/nginx.conf.template /etc/nginx/nginx.conf.template
COPY tools/init.sh /usr/local/bin/init.sh

RUN chmod +x /usr/local/bin/init.sh

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["nginx", "-g", "daemon off;"]