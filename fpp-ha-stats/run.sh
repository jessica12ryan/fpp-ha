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

# 1. Start the main API Web Server engine (Runs continuously on port 7654)
# GITHUB_TOKEN=false ensures it skips using your API_KEY as a GitHub OAuth token
echo "Launching Statistics Web API Server Engine..."
GITHUB_TOKEN=false OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=server node index.js &
SERVER_PID=$!

# 2. Move to the website asset folder and serve it internally on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..."
cd "$WEBSITE_DIR"
http-server -p 80 &
HTTP_PID=$!

# 3. Dynamic background loop targeting the backend collector engine directly
(
    # Give the primary server 5 seconds to warm up first
    sleep 5
    while true; do
        echo "[Collector Loop] Running data aggregation pass straight through backend library modules..."
        # Running the collector script directly completely avoids port 7654 conflicts!
        OUTPUT_DIR="/tmp/output" node -e "
            const Collector = require('/app/server/lib/collector.js');
            const col = new Collector();
            col.run().then(() => console.log('[Collector Loop] Aggregation pass finished successfully.')).catch(err => console.error('[Collector Loop] Error:', err));
        "
        echo "[Collector Loop] Sleeping for 5 minutes..."
        sleep 300
    done
) &
COLLECTOR_LOOP_PID=$!

# Keep container alive and track essential tasks
wait $SERVER_PID $HTTP_PID