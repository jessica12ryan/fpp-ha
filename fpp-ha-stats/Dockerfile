ARG BUILD_FROM=ghcr.io/hassio-addons/base:17.0.0
FROM ${BUILD_FROM}

RUN apk add --no-cache git nodejs npm

RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

RUN cd /app/server && npm install && \
    cd /app/statsCollector && npm install

# Copy service definition
COPY services /etc/services.d

# Force /init to be the primary entrypoint
ENTRYPOINT ["/init"]