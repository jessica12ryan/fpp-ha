#!/bin/bash

# Define physical paths
STORAGE_DIR="/data/storage"
WEBSITE_DIR="/app/website"

# Ensure host persistent directories exist
mkdir -p "$STORAGE_DIR/data"
mkdir -p "$STORAGE_DIR/processed"

# Link storage folders into the server application workspace
mkdir -p /app/server
ln -sf "$STORAGE_DIR/data" /app/server/data
ln -sf "$STORAGE_DIR/processed" /app/server/processed

# Crucial Link: Map the summary file output straight into the web directory
ln -sf "$STORAGE_DIR/summary.json" "$WEBSITE_DIR/summary.json"

# Move to the application engine path
cd /app/server

# Start the collector daemon mode (compiles summary.json)
echo "Launching Statistics Collector Daemon..."
FPP_STATS_MODE=collector node index.js &

# Start the web API engine mode (accepts check-ins from FPP instances)
echo "Launching Statistics Web API Server Engine..."
FPP_STATS_MODE=server node index.js &

# Move to the website asset folder and serve it on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..."
cd "$WEBSITE_DIR"
http-server -p 80 &

# Monitor processes
wait -n