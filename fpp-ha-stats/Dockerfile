FROM alpine:3.19

# Install baseline application environments and git
RUN apk add --no-cache git nodejs npm bash

# Clone the target application repository
RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

# Run dependencies install once (both scripts live here)
RUN cd /app/server && npm install

# Build direct runtime asset
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app
ENTRYPOINT ["/bin/bash", "/run.sh"]