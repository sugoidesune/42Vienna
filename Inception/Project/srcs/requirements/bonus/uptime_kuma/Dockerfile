# -------------------------
# Builder
# -------------------------
FROM alpine:3.23 AS builder

ARG KUMA_VERSION=2.5.3

RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    python3 \
    make \
    g++

RUN git clone \
    --depth 1 \
    --branch "${KUMA_VERSION}" \
    https://github.com/louislam/uptime-kuma.git \
    /app

WORKDIR /app

RUN npm run setup \
    && rm -rf /app/.git \
    && rm -rf /root/.npm \
    && rm -rf /tmp/*


# -------------------------
# Runtime
# -------------------------
FROM alpine:3.23

RUN apk add --no-cache \
    nodejs \
    python3 \
    py3-pip \
    curl \
    && pip install \
        --break-system-packages \
        --no-cache-dir \
        uptime-kuma-api \
    && rm -rf /root/.cache \
    && rm -rf /tmp/*

COPY --from=builder /app /app

WORKDIR /app

COPY tools/init.sh /usr/local/bin/init.sh
COPY tools/kuma_monitors.py /app/tools/kuma_monitors.py

RUN adduser -D kuma \
    && mkdir -p /app/data \
    && chmod +x /usr/local/bin/init.sh \
    && chown -R kuma:kuma /app

USER kuma

VOLUME /app/data

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD curl -f http://localhost:3001 || exit 1

ENTRYPOINT ["/usr/local/bin/init.sh"]

CMD ["node", "server/server.js"]