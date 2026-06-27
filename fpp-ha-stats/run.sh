#!/bin/sh
# Launch processes manually and track them
cd /app/server
node server.js &
PID1=$!
cd /app/statsCollector
node collector.js &
PID2=$!
wait $PID1 $PID2