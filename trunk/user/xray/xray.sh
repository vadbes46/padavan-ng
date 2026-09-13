#!/bin/sh
# Xray service management script for Padavan
# Supports both in-ROM (/usr/bin/xray) and USB/SD-card standalone deployments

PID_FILE="/var/run/xray.pid"
LOG_FILE="/var/log/xray.log"
ETC_DIR="/etc"
[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/xray"
CONF_FILE="${CONF_DIR}/config.json"

log() {
    echo "$@"
    logger -t "xray" "$@"
}

find_binary() {
    # 1. In firmware
    if [ -x "/usr/bin/xray" ]; then
        echo "/usr/bin/xray"
        return 0
    fi

    # 2. Entware
    if [ -x "/opt/bin/xray" ]; then
        echo "/opt/bin/xray"
        return 0
    fi

    # 3. Persistent storage
    if [ -x "${CONF_DIR}/xray" ]; then
        echo "${CONF_DIR}/xray"
        return 0
    fi

    # 4. Mounted USB/microSD/NAND-RWFS storage
    for p in /media/*/xray/xray /media/*/*/xray; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done

    # 5. Temporary directory
    if [ -x "/tmp/xray" ]; then
        echo "/tmp/xray"
        return 0
    fi

    return 1
}

find_config() {
    # 1. Config saved from Web UI in /etc/storage
    if [ -s "${ETC_DIR}/xray_config.json" ]; then
        echo "${ETC_DIR}/xray_config.json"
        return 0
    fi

    # 2. Standard config in /etc/storage/xray/
    if [ -s "$CONF_FILE" ]; then
        echo "$CONF_FILE"
        return 0
    fi

    # 2. Config on mounted USB/microSD storage
    for c in /media/*/xray/config.json /media/*/*/config.json; do
        if [ -s "$c" ]; then
            echo "$c"
            return 0
        fi
    done

    # 3. Fallback to read-only template
    if [ -s "/etc_ro/xray/config.json.vless" ]; then
        mkdir -p -m 755 "$CONF_DIR"
        cp -f "/etc_ro/xray/config.json.vless" "$CONF_FILE"
        chmod 644 "$CONF_FILE"
        [ -x "/sbin/mtd_storage.sh" ] && /sbin/mtd_storage.sh save >/dev/null 2>&1
        echo "$CONF_FILE"
        return 0
    fi

    return 1
}

find_assets() {
    for a in /media/*/xray /media/*/*/xray /opt/share/xray /usr/share/xray; do
        if [ -f "$a/geoip.dat" ]; then
            echo "$a"
            return 0
        fi
    done
    return 1
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    pidof xray >/dev/null 2>&1
}

start() {
    if is_running; then
        log "xray is already running (PID: $(cat "$PID_FILE" 2>/dev/null || pidof xray))"
        return 0
    fi

    local bin=$(find_binary)
    if [ -z "$bin" ]; then
        log "ERROR: xray binary not found! Please place 'xray' executable in /usr/bin/, /opt/bin/, or on USB storage under /media/*/xray/xray"
        return 1
    fi

    local conf=$(find_config)
    if [ -z "$conf" ]; then
        log "ERROR: xray configuration file not found! Please create $CONF_FILE or place config.json on USB storage."
        return 1
    fi

    local asset_dir=$(find_assets)
    if [ -n "$asset_dir" ]; then
        export XRAY_LOCATION_ASSET="$asset_dir"
    fi

    log "Starting xray using $bin with config $conf..."
    "$bin" run -c "$conf" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log "xray started successfully (PID: $pid)"
        return 0
    else
        log "ERROR: xray failed to start. Check $LOG_FILE for details:"
        [ -f "$LOG_FILE" ] && tail -n 10 "$LOG_FILE" | while read -r line; do log "  $line"; done
        rm -f "$PID_FILE"
        return 1
    fi
}

stop() {
    log "Stopping xray..."
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
    fi

    killall -q xray 2>/dev/null
    sleep 1
    killall -9 -q xray 2>/dev/null

    log "xray stopped."
}

status() {
    local bin=$(find_binary)
    local conf=$(find_config)
    local asset_dir=$(find_assets)

    echo "--- xray service status ---"
    echo "Binary location: ${bin:-NOT FOUND}"
    echo "Config location: ${conf:-NOT FOUND}"
    echo "Assets location: ${asset_dir:-NOT FOUND}"

    if is_running; then
        local pids=$(pidof xray)
        echo "Status: RUNNING (PID: $pids)"
        echo ""
        echo "Listening ports (SOCKS / HTTP / Dokodemo):"
        netstat -tlpn 2>/dev/null | grep xray || echo "  (netstat details unavailable)"
        echo ""
        echo "Recent logs (last 5 lines):"
        [ -f "$LOG_FILE" ] && tail -n 5 "$LOG_FILE"
    else
        echo "Status: STOPPED"
    fi
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        sleep 1
        start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
