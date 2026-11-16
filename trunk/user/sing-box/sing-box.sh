#!/bin/sh
# Sing-box service management script for Padavan
# Supports both in-ROM (/usr/bin/sing-box) and USB/SD-card standalone deployments

PID_FILE="/var/run/sing-box.pid"
LOG_FILE="/var/log/sing-box.log"
ETC_DIR="/etc"
[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/sing-box"
CONF_FILE="${CONF_DIR}/config.json"
REMOTE_NETWORK_LIST="${ETC_DIR}/vpnc_remote_network.list"
EXCLUDE_NETWORK_LIST="${ETC_DIR}/vpnc_exclude_network.list"

TABLE=53
PREF_SUPPRESS=5380
PREF_MAIN=5381
PREF_SB=5382
IF_NAME="tun0"

log() {
    echo "$@"
    logger -t "sing-box" "$@"
}

# Portable command lookup: BusyBox ash may be built without CONFIG_ASH_CMDCMD
has_cmd() {
    local c="$1"
    which "$c" >/dev/null 2>&1 && return 0
    [ -x "/sbin/$c" ] || [ -x "/usr/sbin/$c" ] || [ -x "/bin/$c" ] || [ -x "/usr/bin/$c" ] || [ -x "/opt/sbin/$c" ] || [ -x "/opt/bin/$c" ]
}

find_binary() {
    # 1. In firmware
    if [ -f "/usr/bin/sing-box" -a -x "/usr/bin/sing-box" ]; then
        echo "/usr/bin/sing-box"
        return 0
    fi

    # 2. Entware
    if [ -f "/opt/bin/sing-box" -a -x "/opt/bin/sing-box" ]; then
        echo "/opt/bin/sing-box"
        return 0
    fi

    # 3. Persistent storage
    if [ -f "${CONF_DIR}/sing-box" -a -x "${CONF_DIR}/sing-box" ]; then
        echo "${CONF_DIR}/sing-box"
        return 0
    fi

    # 4. Mounted USB/microSD storage
    for p in /media/*/sing-box/sing-box /media/*/*/sing-box/sing-box /media/*/*/sing-box; do
        if [ -f "$p" -a -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done

    # 5. Temporary directory
    if [ -f "/tmp/sing-box" -a -x "/tmp/sing-box" ]; then
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
    for c in /media/*/sing-box/config.json /media/*/*/sing-box/config.json /media/*/*/config.json; do
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

get_server_hosts() {
    local conf="$1"
    [ -s "$conf" ] || return 0
    tr '\n\r\t' '   ' < "$conf" | awk -v RS='{' '
        /"server"[[:space:]]*:[[:space:]]*"[^"]+"/ && /"server_port"[[:space:]]*:/ {
            s = substr($0, match($0, /"server"[[:space:]]*:[[:space:]]*"[^"]+"/), RLENGTH)
            sub(/.*"server"[[:space:]]*:[[:space:]]*"/, "", s)
            sub(/".*/, "", s)
            if (s != "" && s != "0.0.0.0" && s !~ /^127\./) print s
        }
    ' | sort -u
}

resolve_ipv4() {
    local host="$1"
    case "$host" in
        [0-9]*.[0-9]*.[0-9]*.[0-9]*)
            echo "$host"
            return 0
            ;;
    esac
    nslookup "$host" 2>/dev/null | awk '
        /^Name/ { found=1; next }
        found && /^Address/ {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) print $i
            }
        }
    ' | sort -u
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

routing_stop() {
    local ipbb=$(ip 2>&1 | grep -i busybox)
    local p pref
    for pref in $PREF_SUPPRESS $PREF_MAIN $PREF_SB; do
        if [ "$ipbb" ]; then
            while ip rule del pref $pref 2>/dev/null; do true; done
        else
            for p in 4 6; do
                while ip -$p rule del pref $pref 2>/dev/null; do true; done
            done
        fi
    done
    if [ "$ipbb" ]; then
        ip route flush table $TABLE 2>/dev/null || ip route del default table $TABLE 2>/dev/null || true
    else
        for p in 4 6; do
            ip -$p route flush table $TABLE 2>/dev/null || true
        done
    fi
}

routing_start() {
    local vpnc_en="0" vpnc_tp="" routing="" conf=""
    local ipbb=$(ip 2>&1 | grep -i busybox)

    if has_cmd nvram; then
        vpnc_en=$(nvram get vpnc_enable 2>/dev/null)
        vpnc_tp=$(nvram get vpnc_type 2>/dev/null)
        routing=$(nvram get vpnc_sb_routing 2>/dev/null)
    fi
    [ -n "$routing" ] || routing="0"

    routing_stop

    if ! is_running && [ "${vpnc_en}_${vpnc_tp}" != "1_5" ]; then
        return 0
    fi

    # Wait briefly for sing-box to initialize tun0
    local i=0
    while [ $i -lt 5 ]; do
        ip link show dev "$IF_NAME" >/dev/null 2>&1 && break
        sleep 1
        i=$((i + 1))
    done

    if ! ip link show dev "$IF_NAME" >/dev/null 2>&1; then
        log "tun0 interface not active; skipping tun0 policy routing."
        return 0
    fi

    ip link set dev "$IF_NAME" up 2>/dev/null || true

    conf=$(find_config)
    if [ ! "$ipbb" ]; then
        for p in 4 6; do
            ip -$p rule add table main suppress_prefixlength 0 pref $PREF_SUPPRESS 2>/dev/null || true
            ip -$p rule add table $TABLE pref $PREF_SB 2>/dev/null || true
        done
    else
        local wan0_gw="" wan0_if=""
        if has_cmd nvram; then
            wan0_gw=$(nvram get wan0_gateway 2>/dev/null)
            wan0_if=$(nvram get wan0_ifname 2>/dev/null)
        fi
        [ -n "$wan0_gw" -a -n "$wan0_if" ] && ip route add default via "$wan0_gw" dev "$wan0_if" table $TABLE 2>/dev/null || true
    fi

    # Exclude configured LAN source CIDRs from VPN
    if [ -s "$EXCLUDE_NETWORK_LIST" ]; then
        for cidr in $(awk '{sub(/\r$/,""); sub(/[[:space:]]*#.*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); if($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/ || $0 ~ /^[0-9a-fA-F:]+(\/[0-9]+)?$/) print $0}' "$EXCLUDE_NETWORK_LIST" | sort -u); do
            if [ "$ipbb" ]; then
                case "$cidr" in
                    */0|*:*) continue ;;
                esac
                ip rule add from "$cidr" table $TABLE pref $PREF_MAIN 2>/dev/null || true
            else
                local p=4
                [ "$cidr" != "${cidr#*:}" ] && p=6
                ip -$p rule add from "$cidr" table main pref $PREF_MAIN 2>/dev/null || true
            fi
        done
    fi

    # Ensure WAN IPs and proxy server endpoints always use main table
    if has_cmd nvram; then
        for var in wan_ipaddr wan0_ipaddr; do
            local ip_val=$(nvram get "$var" 2>/dev/null)
            [ -n "$ip_val" -a "$ip_val" != "0.0.0.0" ] || continue
            if [ "$ipbb" ]; then
                ip rule add from "$ip_val" table $TABLE pref $PREF_MAIN 2>/dev/null || true
            else
                ip -4 rule add from "$ip_val" table main pref $PREF_MAIN 2>/dev/null || true
            fi
        done
    fi

    local srv="" srv_ip=""
    for srv in $(get_server_hosts "$conf"); do
        for srv_ip in $(resolve_ipv4 "$srv"); do
            if [ "$ipbb" ]; then
                ip rule add to "$srv_ip" table $TABLE pref $PREF_MAIN 2>/dev/null || true
            else
                ip -4 rule add to "$srv_ip" table main pref $PREF_MAIN 2>/dev/null || true
            fi
        done
    done

    if [ "$routing" = "0" ]; then
        if [ "$ipbb" ]; then
            ip route replace 0/1 dev "$IF_NAME" 2>/dev/null || ip route add 0/1 dev "$IF_NAME"
            ip route replace 128/1 dev "$IF_NAME" 2>/dev/null || ip route add 128/1 dev "$IF_NAME"
        else
            ip -4 route replace default dev "$IF_NAME" table $TABLE 2>/dev/null || true
        fi
        log "Sing-box policy routing enabled on $IF_NAME (mode: Full traffic)."
    else
        if [ -s "$REMOTE_NETWORK_LIST" ]; then
            if [ "$ipbb" ]; then
                for cidr in $(awk '{sub(/\r$/,""); sub(/[[:space:]]*#.*/,""); gsub(/^[[:space:]]+|[[:space:]]+$/,""); if($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/ && $0 !~ /\/0$/) print $0}' "$REMOTE_NETWORK_LIST" | sort -u); do
                    ip route replace "$cidr" dev "$IF_NAME" 2>/dev/null || ip route add "$cidr" dev "$IF_NAME" 2>/dev/null || true
                done
            else
                awk -v dev="$IF_NAME" -v tbl="$TABLE" '
                    {
                        sub(/\r$/, "")
                        sub(/[[:space:]]*#.*/, "")
                        gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                        if ($0 == "" || $0 ~ /:/ || $0 ~ /\/0$/) next
                        if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/)
                            print "route replace " $0 " dev " dev " table " tbl
                    }
                ' "$REMOTE_NETWORK_LIST" | sort -u | ip -batch - 2>/dev/null || true
            fi
        fi
        log "Sing-box policy routing enabled on $IF_NAME (mode: Unblock list)."
    fi
}

start() {
    if is_running; then
        log "sing-box is already running (PID: $(cat "$PID_FILE" 2>/dev/null || pidof sing-box))"
        routing_start
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

    export GOGC=25
    export GOMEMLIMIT=48MiB

    log "Starting sing-box using $bin with config $conf..."
    "$bin" run -c "$conf" --disable-color > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log "sing-box started successfully (PID: $pid)"
        routing_start
        return 0
    else
        log "ERROR: sing-box failed to start. Check $LOG_FILE for details:"
        [ -f "$LOG_FILE" ] && tail -n 10 "$LOG_FILE" | while read -r line; do log "  $line"; done
        rm -f "$PID_FILE"
        return 1
    fi
}

stop() {
    local was_running=0
    is_running && was_running=1
    log "Stopping sing-box..."
    routing_stop

    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null
        rm -f "$PID_FILE"
    fi

    killall -q sing-box 2>/dev/null
    sleep 1
    killall -9 -q sing-box 2>/dev/null

    # Clean up tun0 only if sing-box actually created it (avoid touching OpenVPN tun0)
    if [ $was_running -eq 1 ] || (has_cmd nvram && [ "$(nvram get vpnc_type 2>/dev/null)" = "5" ]); then
        ip link delete "$IF_NAME" 2>/dev/null
    fi

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
    firewall)
        routing_start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|firewall|status}"
        exit 1
        ;;
esac
