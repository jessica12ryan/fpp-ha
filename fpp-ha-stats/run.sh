#!/bin/bash

# Enforce Home Assistant persistent storage handoff
mkdir -p /data/storage
if [ -d "/app/storage" ] && [ ! -L "/app/storage" ]; then
    rm -rf /app/storage
fi

if [ ! -L "/app/storage" ]; then
    ln -s /data/storage /app/storage
fi

# Spin up services cleanly
echo "Launching Statistics Collector Daemon..."
cd /app/collector
node collector.js &

echo "Launching Statistics Web API Server Engine..."
cd /app/server
node server.js &

# Monitor processes
wait -n