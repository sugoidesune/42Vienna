FROM debian:12

    # download dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        iproute2 \
        mariadb-client \
        php8.2 \
        php8.2-cli \
        php8.2-fpm \
        php8.2-mysql \
        php8.2-curl \
        php8.2-gd \
        php8.2-mbstring \
        php8.2-redis \
        php8.2-xml \
        php8.2-zip \
        unzip \
    && rm -rf /var/lib/apt/lists/*

    # download wordpress cli & make it executable
RUN curl -o /usr/local/bin/wp \
        https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x /usr/local/bin/wp

    # download wordpress in seperate folder
RUN mkdir -p /usr/src/wordpress \
    && wp core download \
        --allow-root \
        --path=/usr/src/wordpress \
    && curl -fsSL -o /tmp/redis-cache.zip \
        https://downloads.wordpress.org/plugin/redis-cache.2.8.0.zip \
    && unzip -q /tmp/redis-cache.zip \
        -d /usr/src/wordpress/wp-content/plugins \
    && rm /tmp/redis-cache.zip

        # copy config & init files & make executable
COPY conf/www.conf /etc/php/8.2/fpm/pool.d/www.conf
COPY tools/init.sh /usr/local/bin/init.sh
RUN chmod +x /usr/local/bin/init.sh


WORKDIR /var/www/html

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["php-fpm8.2", "-F"]
