FROM alpine:3.24

# Install baseline application environments, git, and a global static file server
# curl is added for HEALTHCHECK (lightweight, no extra daemon)
RUN apk add --no-cache git nodejs npm bash curl && \
    npm install -g http-server@14.1.1

# Clone the target application repository
RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

# Run dependencies install inside the server folder and downgrade octokit to v18 (CommonJS compatible, pinned)
RUN cd /app/server && \
    npm install --omit=dev --no-audit --no-fund && \
    npm install @octokit/rest@18.12.0 --no-audit --no-fund

# NEW: Run dependencies install inside the statsCollector folder
RUN cd /app/statsCollector && \
    npm install --omit=dev --no-audit --no-fund

# Build direct runtime asset
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -fsS http://127.0.0.1:80/ >/dev/null 2>&1 || curl -fsS http://127.0.0.1:7654/ >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/bin/bash", "/run.sh"]