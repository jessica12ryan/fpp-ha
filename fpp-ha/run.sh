#!/bin/bash
set -e

# ============================================================
# FPP - Falcon Player App for Home Assistant
# ============================================================

# Mark as container so FPP skips hardware-specific checks
if [ -f "/.dockerenv" ]; then
    echo "docker" > /etc/fpp/container
fi

PERSISTENT_DIR="/data/fpp-media"
SYNC_INTERVAL=30

# ------------------------------------------------------------------
# Persistent Storage Detection
# ------------------------------------------------------------------
# Check if HA supervisor already provides persistent storage at
# /home/fpp/media (via data:rw map with path: in config.yaml).
# If so, skip all manual persistence logic.
MEDIA_DEV=$(stat -c "%d" /home/fpp/media 2>/dev/null || echo "")
ROOT_DEV=$(stat -c "%d" / 2>/dev/null || echo "")
if [ -n "$MEDIA_DEV" ] && [ -n "$ROOT_DEV" ] && [ "$MEDIA_DEV" != "$ROOT_DEV" ]; then
    echo "[fpp] Supervisor persistent storage active at /home/fpp/media" >&2
    PERSISTENCE_NEEDED=false
else
    echo "[fpp] Persistent storage: $PERSISTENT_DIR" >&2
    PERSISTENCE_NEEDED=true
fi

BIND_MOUNT_OK=false
SYNC_PID=""

if [ "$PERSISTENCE_NEEDED" = true ]; then
    mkdir -p "$PERSISTENT_DIR"
    if mount --bind "$PERSISTENT_DIR" /home/fpp/media 2>&1; then
        BIND_MOUNT_OK=true
        echo "[fpp] Bind mount active" >&2
    else
        echo "[fpp] Using rsync-based persistence" >&2
        # Restore persistent data on subsequent runs
        if [ -f "$PERSISTENT_DIR/settings" ]; then
            echo "[fpp] Restoring persistent data..." >&2
            cp -a "$PERSISTENT_DIR/." /home/fpp/media/ 2>&1
        fi
    fi
fi

# ------------------------------------------------------------------
# FPP Initialization
# ------------------------------------------------------------------
mkdir -p /home/fpp/media/logs
/opt/fpp/src/fppinit start

# First-run save + sync loop (only when we manage persistence ourselves)
if [ "$PERSISTENCE_NEEDED" = true ] && [ "$BIND_MOUNT_OK" = false ]; then
    if [ ! -f "$PERSISTENT_DIR/settings" ]; then
        echo "[fpp] Saving initial defaults to persistent storage..." >&2
        cp -a /home/fpp/media/. "$PERSISTENT_DIR/" 2>&1
    fi
    (
        while true; do
            sleep "$SYNC_INTERVAL"
            rsync -a --delete /home/fpp/media/ "$PERSISTENT_DIR/" >/dev/null 2>&1
        done
    ) &
    SYNC_PID=$!
    echo "[fpp] Sync loop started (PID $SYNC_PID, every ${SYNC_INTERVAL}s)" >&2
fi

# ------------------------------------------------------------------
# Container setup
# ------------------------------------------------------------------
echo "docker" > /etc/fpp/container 2>/dev/null || true

# Apply settings
sed -i 's/^HostName = .*/HostName = "fpp-docker"/' /home/fpp/media/settings || true
sed -i 's/^HostDescription = .*/HostDescription = "Home Assistant FPP"/' /home/fpp/media/settings || true

# ------------------------------------------------------------------
# Fix permissions for web UI write access
# ------------------------------------------------------------------
# fppinit sets ownership to fpp:fpp, but PHP-FPM may run as www-data.
echo "[fpp] Setting permissions..."
chmod -R a+rwX /home/fpp/media/ 2>&1

# ------------------------------------------------------------------
# Signal handling
# ------------------------------------------------------------------
cleanup() {
    echo "[fpp] Shutting down..." >&2
    if [ -n "$SYNC_PID" ]; then
        echo "[fpp] Final sync..." >&2
        kill "$SYNC_PID" 2>/dev/null || true
        rsync -a --delete /home/fpp/media/ "$PERSISTENT_DIR/" >/dev/null 2>&1 || true
    fi
    [ -n "$APACHE_PID" ] && kill "$APACHE_PID" 2>/dev/null || true
    wait 2>/dev/null || true
    echo "[fpp] Shutdown complete" >&2
    exit 0
}
trap cleanup SIGTERM SIGINT

# ------------------------------------------------------------------
# Start services
# ------------------------------------------------------------------
echo "[fpp] Starting FPP daemon..." >&2
/opt/fpp/scripts/fppd_start

echo "[fpp] Starting web server..." >&2
mkdir -p /run/php

PHP_FPM=""
for p in php-fpm8.4 php-fpm8.3 php-fpm8.2 php-fpm; do
    if command -v "$p" >/dev/null 2>&1; then
        PHP_FPM=$(command -v "$p")
        echo "[fpp] Found PHP-FPM: $PHP_FPM" >&2
        break
    fi
done

if [ -n "$PHP_FPM" ]; then
    PHP_CONFIG=$(find /etc/php -maxdepth 3 -name "php-fpm.conf" 2>/dev/null | head -1)
    if [ -n "$PHP_CONFIG" ]; then
        echo "[fpp] Starting $PHP_FPM with config $PHP_CONFIG" >&2
        "$PHP_FPM" --fpm-config "$PHP_CONFIG" 2>&1
        echo "[fpp] PHP-FPM started successfully" >&2
    else
        echo "[fpp] WARNING: No php-fpm.conf found, starting $PHP_FPM without config" >&2
        "$PHP_FPM" 2>&1
    fi
else
    echo "[fpp] WARNING: php-fpm binary not found" >&2
fi

/usr/sbin/apache2ctl -D FOREGROUND &
APACHE_PID=$!
echo "[fpp] Apache started (PID $APACHE_PID)" >&2

wait "$APACHE_PID"
