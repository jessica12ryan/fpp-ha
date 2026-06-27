#!/usr/bin/with-contenv bash
# Manually launch both processes to avoid s6-overlay service directory conflicts
cd /app/server
node server.js &
cd /app/statsCollector
node collector.js &
wait -n