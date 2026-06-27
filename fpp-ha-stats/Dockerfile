ARG BUILD_FROM=ghcr.io/hassio-addons/base:17.0.0
FROM ${BUILD_FROM}

# Install git, node, and npm
RUN apk add --no-cache git nodejs npm

# Clone the repository
RUN git clone https://github.com/FalconChristmas/fpp-stats-server.git /app

# Install node dependencies
RUN cd /app/server && npm install && \
    cd /app/statsCollector && npm install

# Copy s6 service definitions from local repository
COPY services /etc/services.d

# DO NOT include CMD or ENTRYPOINT here. 
# The base image handles the startup automatically.
