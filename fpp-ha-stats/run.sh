#!/bin/bash

# Define physical paths
STORAGE_DIR="/data/storage"
WEBSITE_DIR="/app/website"

# Read the API Key value out of the Home Assistant Configuration options
# Non-breaking: keep default for existing installs but warn loudly.
API_KEY=""
if [ -f "/data/options.json" ]; then
    API_KEY=$(node -e "try{cl=require('/data/options.json'); process.stdout.write(cl.api_key||'')}catch(e){}" 2>/dev/null)
    if [ -z "$API_KEY" ]; then
        API_KEY=$(grep -o '"api_key"[[:space:]]*:[[:space:]]*"[^"]*"' /data/options.json 2>/dev/null | sed -E 's/.*"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' | head -n 1)
    fi
fi

# Fallback default key if parsing failed or file doesn't exist yet
if [ -z "$API_KEY" ]; then
    API_KEY="ChangeMeToASecretKey123"
    echo "[fpp-ha-stats] WARNING: Using default api_key - set a unique api_key in add-on Configuration!" >&2
fi
export API_KEY

# Create the missing directories that the upstream app demands
mkdir -p /tmp/output
mkdir -p "$STORAGE_DIR/data"
mkdir -p "$STORAGE_DIR/processed"

# Link storage folders into the server application workspace
mkdir -p /app/server
ln -sf "$STORAGE_DIR/data" /app/server/data
ln -sf "$STORAGE_DIR/processed" /app/server/processed

# Link storage folders into the statsCollector workspace
mkdir -p /app/statsCollector
ln -sf "$STORAGE_DIR/data" /app/statsCollector/data
ln -sf "$STORAGE_DIR/processed" /app/statsCollector/processed

# Map the website summary output straight into the web directory
ln -sf /tmp/output/summary.json "$WEBSITE_DIR/summary.json"

# Patch: Force Octokit to run anonymously so it stops using API_KEY as a GitHub token
# Robust: checks multiple possible upstream paths and is idempotent
for _gh_file in /app/server/lib/github.js /app/server/src/github.js /app/server/lib/github.ts /app/server/src/github.ts; do
    if [ -f "$_gh_file" ]; then
        if grep -q "process.env.API_KEY" "$_gh_file" 2>/dev/null; then
            sed -i "s/auth:[[:space:]]*process\.env\.API_KEY/auth: undefined/g" "$_gh_file" 2>/dev/null || true
            echo "[fpp-ha-stats] Patched Octokit auth in $_gh_file" >&2
        fi
    fi
done
unset _gh_file

# Initialize PIDs for cleanup/wait (non-breaking: empty values are ignored)
SERVER_PID=""
HTTP_PID=""
COLLECTOR_LOOP_PID=""

# 1. Start the main API Web Server engine (Runs continuously on port 7654)
echo "Launching Statistics Web API Server Engine..." >&2
if ! cd /app/server 2>&1; then
    echo "[fpp-ha-stats] ERROR: /app/server not found" >&2
else
    OUTPUT_DIR="/tmp/output" FPP_STATS_MODE=server node index.js &
    SERVER_PID=$!
    echo "[fpp-ha-stats] Server PID $SERVER_PID" >&2
fi

# 2. Move to the website asset folder and serve it internally on port 80
echo "Launching Statistics Web Frontend Interface Dashboard..." >&2
if ! cd "$WEBSITE_DIR" 2>&1; then
    echo "[fpp-ha-stats] ERROR: $WEBSITE_DIR not found" >&2
else
    http-server -p 80 &
    HTTP_PID=$!
    echo "[fpp-ha-stats] Frontend PID $HTTP_PID" >&2
fi

# 3. Dynamic background loop targeting the true statsCollector package
# Non-breaking: resilient to transient node failures; never exit collector loop
(
    # Give the primary server 5 seconds to warm up first
    sleep 5
    while true; do
        echo "[Collector Loop] Running data aggregation pass in statsCollector folder..." >&2
        if ! cd /app/statsCollector 2>&1; then
            echo "[Collector Loop] WARNING: /app/statsCollector missing, retrying in 60s" >&2
            sleep 60
            continue
        fi
        if ! OUTPUT_DIR="/tmp/output" node index.js 2>&1; then
            echo "[Collector Loop] WARNING: aggregation pass failed (exit $?), retrying after sleep" >&2
        else
            echo "[Collector Loop] Aggregation pass finished. Sleeping for 5 minutes..." >&2
        fi
        sleep 300
    done
) &
COLLECTOR_LOOP_PID=$!

# Trap SIGTERM and SIGINT for graceful shutdown
cleanup() {
    echo "[fpp-ha-stats] Shutting down gracefully..."
    kill -TERM $SERVER_PID $HTTP_PID $COLLECTOR_LOOP_PID 2>/dev/null
    wait $SERVER_PID $HTTP_PID $COLLECTOR_LOOP_PID 2>/dev/null
    echo "[fpp-ha-stats] Shutdown complete"
    exit 0
}
trap cleanup SIGTERM SIGINT

# Keep container alive and track essential tasks
wait $SERVER_PID $HTTP_PID $COLLECTOR_LOOP_PID
