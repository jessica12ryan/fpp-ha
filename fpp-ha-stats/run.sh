#!/bin/bash

# Enforce Home Assistant persistent storage handoff
mkdir -p /data/storage
if [ -d "/app/storage" ] && [ ! -L "/app/storage" ]; then
    rm -rf /app/storage
fi

if [ ! -L "/app/storage" ]; then
    ln -s /data/storage /app/storage
fi

# Change directory to the server application directory
cd /app/server

# Start the collector daemon mode by telling index.js to handle collection tasks
echo "Launching Statistics Collector Daemon..."
FPP_STATS_MODE=collector node index.js &

# Start the web API engine mode
echo "Launching Statistics Web API Server Engine..."
FPP_STATS_MODE=server node index.js &

# Move to the website asset folder and serve it on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..."
cd /app/website
http-server -p 80 &

# Monitor processes
wait -n