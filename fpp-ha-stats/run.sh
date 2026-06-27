#!/bin/bash

# Define physical paths
STORAGE_DIR="/data/storage"
WEBSITE_DIR="/app/website"

# Read the API Key value out of the Home Assistant Configuration options
if [ -f "/data/options.json" ]; then
    export API_KEY=$(node -e "echo require('/data/options.json').api_key" 2>/dev/null || cat /data/options.json | grep -o '"api_key": "[^"]*' | grep -o '[^"]*$')
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

# Start the collector daemon mode
echo "Launching Statistics Collector Daemon..."
OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=collector node index.js &

# Start the web API engine mode using the parsed token asset
echo "Launching Statistics Web API Server Engine..."
OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=server node index.js &

# Move to the website asset folder and serve it on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..."
cd "$WEBSITE_DIR"
http-server -p 80 &

# Monitor processes
wait -n