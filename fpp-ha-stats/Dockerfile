FROM alpine:3.19

# Install baseline application environments, git, and a global static file server
RUN apk add --no-cache git nodejs npm bash && \
    npm install -g http-server

# Clone the target application repository
RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

# Run dependencies install inside the server folder and downgrade octokit to v18 (CommonJS compatible)
RUN cd /app/server && \
    npm install && \
    npm install @octokit/rest@18

# Build direct runtime asset
COPY run.sh /run.sh
RUN chmod +x /run.sh

WORKDIR /app
ENTRYPOINT ["/bin/bash", "/run.sh"]