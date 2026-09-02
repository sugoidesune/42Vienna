FROM alpine:3.23

# Copy the busybox build config (limited to httpd)
COPY conf/.config /tmp/.config

# Install dependencies, compile busybox httpd, install binary, and purge build tools
RUN apk add --no-cache gcc musl-dev make perl \
  && wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2 \
  && tar xf busybox-1.35.0.tar.bz2 \
  && cd busybox-1.35.0 \
  && cp /tmp/.config .config \
  && make -j$(nproc) \
  && make install \
  && cp _install/bin/busybox /usr/local/bin/httpd \
  && cd / \
  && rm -rf /busybox-1.35.0 /busybox-1.35.0.tar.bz2 /tmp/.config \
  && apk del gcc musl-dev make perl

# Create non-root user and web root
RUN adduser -D static \
  && mkdir -p /var/www/static \
  && chown -R static:static /var/www/static

WORKDIR /var/www/static

# Copy static website files
COPY html/ .

USER static

EXPOSE 3000

CMD ["/usr/local/bin/httpd", "-f", "-v", "-p", "3000", "-h", "/var/www/static"]
