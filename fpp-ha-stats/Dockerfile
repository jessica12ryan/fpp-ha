FROM alpine:3.19

# Install baseline application environments, git, and a global static file server
RUN apk add --no-cache git nodejs npm bash && \
    npm install -g http-server

# Clone the target application repository
RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

# Run dependencies install inside the server folder (where index.js and collector.js live)
RUN cd /app/server && npm install

# Build direct runtime asset
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app
ENTRYPOINT ["/bin/bash", "/run.sh"]