#!/bin/bash

# Define physical paths
STORAGE_DIR="/data/storage"
WEBSITE_DIR="/app/website"

# Read the API Key value out of the Home Assistant Configuration options
if [ -f "/data/options.json" ]; then
    export API_KEY=$(node -e "cl=require('/data/options.json'); console.log(cl.api_key)" 2>/dev/null || cat /data/options.json | grep -o '"api_key": "[^"]*' | grep -o '[^"]*$')
fi

# Fallback default key if parsing failed or file doesn't exist yet
if [ -z "$API_KEY" ]; then
    export API_KEY="ChangeMeToASecretKey123"
fi

# Create the missing directories that the upstream app demands
mkdir -p /tmp/output
mkdir -p "$STORAGE_DIR/data"
mkdir -p "$STORAGE_DIR/processed"

# Link storage folders into the server application workspace
mkdir -p /app/server
ln -sf "$STORAGE_DIR/data" /app/server/data
ln -sf "$STORAGE_DIR/processed" /app/server/processed

# Map the website summary output straight into the web directory
ln -sf /tmp/output/summary.json "$WEBSITE_DIR/summary.json"

# Move to the application engine path
cd /app/server

# 1. Start the main API Web Server engine (Runs continuously)
echo "Launching Statistics Web API Server Engine..."
OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=server node index.js &
SERVER_PID=$!

# 2. Move to the website asset folder and serve it on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..."
cd "$WEBSITE_DIR"
http-server -p 80 &
HTTP_PID=$!

# 3. Dynamic background loop for the Data Collector aggregation pass
(
    cd /app/server
    # Give the server a few seconds to fully initialize first
    sleep 5
    while true; do
        echo "[Collector Loop] Running data aggregation pass to compile summary.json..."
        OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=collector node index.js
        echo "[Collector Loop] Pass complete. Sleeping for 5 minutes..."
        sleep 300
    done
) &
COLLECTOR_LOOP_PID=$!

# Keep container alive and track essential tasks
wait $SERVER_PID $HTTP_PID