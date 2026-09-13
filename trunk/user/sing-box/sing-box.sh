#!/bin/sh
# Sing-box service management script for Padavan
# Supports both in-ROM (/usr/bin/sing-box) and USB/SD-card standalone deployments

PID_FILE="/var/run/sing-box.pid"
LOG_FILE="/var/log/sing-box.log"
ETC_DIR="/etc"
[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/sing-box"
CONF_FILE="${CONF_DIR}/config.json"

log() {
    echo "$@"
    logger -t "sing-box" "$@"
}

find_binary() {
    # 1. In firmware
    if [ -x "/usr/bin/sing-box" ]; then
        echo "/usr/bin/sing-box"
        return 0
    fi

    # 2. Entware
    if [ -x "/opt/bin/sing-box" ]; then
        echo "/opt/bin/sing-box"
        return 0
    fi

    # 3. Persistent storage
    if [ -x "${CONF_DIR}/sing-box" ]; then
        echo "${CONF_DIR}/sing-box"
        return 0
    fi

    # 4. Mounted USB/microSD storage
    for p in /media/*/sing-box/sing-box /media/*/sing-box /media/*/*/sing-box; do
        if [ -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done

    # 5. Temporary directory
    if [ -x "/tmp/sing-box" ]; then
        echo "/tmp/sing-box"
        return 0
    fi

    return 1
}

find_config() {
    # 1. Config saved from Web UI in /etc/storage
    if [ -s "${ETC_DIR}/singbox_config.json" ]; then
        echo "${ETC_DIR}/singbox_config.json"
        return 0
    fi

    # 2. Standard config in /etc/storage/sing-box/
    if [ -s "$CONF_FILE" ]; then
        echo "$CONF_FILE"
        return 0
    fi

    # 2. Config on mounted USB/microSD storage
    for c in /media/*/sing-box/config.json /media/*/*/config.json; do
        if [ -s "$c" ]; then
            echo "$c"
            return 0
        fi
    done

    # 3. Fallback to read-only template
    if [ -s "/etc_ro/sing-box/config.json.vless" ]; then
        mkdir -p -m 755 "$CONF_DIR"
        cp -f "/etc_ro/sing-box/config.json.vless" "$CONF_FILE"
        chmod 644 "$CONF_FILE"
        [ -x "/sbin/mtd_storage.sh" ] && /sbin/mtd_storage.sh save >/dev/null 2>&1
        echo "$CONF_FILE"
        return 0
    fi

    return 1
}

is_running() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    pidof sing-box >/dev/null 2>&1
}

start() {
    if is_running; then
        log "sing-box is already running (PID: $(cat "$PID_FILE" 2>/dev/null || pidof sing-box))"
        return 0
    fi

    local bin=$(find_binary)
    if [ -z "$bin" ]; then
        log "ERROR: sing-box binary not found! Please place 'sing-box' executable in /usr/bin/, /opt/bin/, or on a USB flash drive under /media/*/sing-box/sing-box"
        return 1
    fi

    local conf=$(find_config)
    if [ -z "$conf" ]; then
        log "ERROR: sing-box configuration file not found! Please create $CONF_FILE or place config.json on USB storage."
        return 1
    fi

    # Ensure /dev/net/tun exists
    if [ ! -c /dev/net/tun ]; then
        mkdir -p /dev/net
        mknod /dev/net/tun c 10 200
        chmod 600 /dev/net/tun
    fi

    # Ensure kernel tun module is loaded if modular
    [ -f /lib/modules/*/kernel/drivers/net/tun.ko ] && modprobe tun 2>/dev/null

    log "Starting sing-box using $bin with config $conf..."
    "$bin" run -c "$conf" --disable-color > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log "sing-box started successfully (PID: $pid)"
        return 0
    else
        log "ERROR: sing-box failed to start. Check $LOG_FILE for details:"
        [ -f "$LOG_FILE" ] && tail -n 10 "$LOG_FILE" | while read -r line; do log "  $line"; done
        rm -f "$PID_FILE"
        return 1
    fi
}

stop() {
    log "Stopping sing-box..."
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
    fi

    killall -q sing-box 2>/dev/null
    sleep 1
    killall -9 -q sing-box 2>/dev/null

    # Clean up tun interface if left over
    ip link delete tun0 2>/dev/null

    log "sing-box stopped."
}

status() {
    local bin=$(find_binary)
    local conf=$(find_config)

    echo "--- sing-box service status ---"
    echo "Binary location: ${bin:-NOT FOUND}"
    echo "Config location: ${conf:-NOT FOUND}"

    if is_running; then
        local pids=$(pidof sing-box)
        echo "Status: RUNNING (PID: $pids)"
        echo ""
        echo "Active network interfaces:"
        ip -brief address show tun0 2>/dev/null || echo "  (tun0 interface not active)"
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
