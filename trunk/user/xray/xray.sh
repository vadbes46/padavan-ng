#!/bin/sh
# Xray service management script for Padavan
# Supports both in-ROM (/usr/bin/xray) and USB/SD-card standalone deployments

PID_FILE="/var/run/xray.pid"
LOG_FILE="/var/log/xray.log"
ETC_DIR="/etc"
[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/xray"
CONF_FILE="${CONF_DIR}/config.json"
REMOTE_NETWORK_LIST="${ETC_DIR}/vpnc_remote_network.list"
EXCLUDE_NETWORK_LIST="${ETC_DIR}/vpnc_exclude_network.list"

log() {
    echo "$@"
    logger -t "xray" "$@"
}

find_binary() {
    # 1. In firmware
    if [ -f "/usr/bin/xray" -a -x "/usr/bin/xray" ]; then
        echo "/usr/bin/xray"
        return 0
    fi

    # 2. Entware
    if [ -f "/opt/bin/xray" -a -x "/opt/bin/xray" ]; then
        echo "/opt/bin/xray"
        return 0
    fi

    # 3. Persistent storage
    if [ -f "${CONF_DIR}/xray" -a -x "${CONF_DIR}/xray" ]; then
        echo "${CONF_DIR}/xray"
        return 0
    fi

    # 4. Mounted USB/microSD/NAND-RWFS storage
    for p in /media/*/xray/xray /media/*/*/xray/xray /media/*/*/xray; do
        if [ -f "$p" -a -x "$p" ]; then
            echo "$p"
            return 0
        fi
    done

    # 5. Temporary directory
    if [ -f "/tmp/xray" -a -x "/tmp/xray" ]; then
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
    for c in /media/*/xray/config.json /media/*/*/xray/config.json /media/*/*/config.json; do
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

get_redir_port() {
    local conf="$1"
    local port=""
    if [ -s "$conf" ]; then
        port=$(tr '\n\r\t' '   ' < "$conf" | awk -v RS='{' '
            /"dokodemo-door"/ {
                if (match($0, /"port"[[:space:]]*:[[:space:]]*[0-9]+/)) {
                    s = substr($0, RSTART, RLENGTH)
                    gsub(/[^0-9]/, "", s)
                    if (s != "") { print s; exit }
                }
            }
        ')
    fi
    case "$port" in
        ''|*[!0-9]*) port="1082" ;;
    esac
    echo "$port"
}

get_server_hosts() {
    local conf="$1"
    [ -s "$conf" ] || return 0
    tr '\n\r\t' '   ' < "$conf" | awk -v RS='{' '
        /"address"[[:space:]]*:[[:space:]]*"[^"]+"/ {
            s = substr($0, match($0, /"address"[[:space:]]*:[[:space:]]*"[^"]+"/), RLENGTH)
            sub(/.*"address"[[:space:]]*:[[:space:]]*"/, "", s)
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

load_ipset_cidrs() {
    local set_name="$1"
    local list_file="$2"
    [ -s "$list_file" ] || return 0
    awk -v sname="$set_name" '
        {
            sub(/\r$/, "")
            sub(/[[:space:]]*#.*/, "")
            gsub(/^[[:space:]]+|[[:space:]]+$/, "")
            if ($0 == "" || $0 ~ /:/) next
            if ($0 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(\/[0-9]+)?$/)
                print "add " sname " " $0
        }
    ' "$list_file" | sort -u | ipset restore -! 2>/dev/null
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

firewall_stop() {
    local lan_if=""
    command -v nvram >/dev/null 2>&1 && lan_if=$(nvram get lan_ifname 2>/dev/null)
    [ -n "$lan_if" ] || lan_if="br0"

    while iptables -t nat -D PREROUTING -i "$lan_if" -p tcp -j XRAY_REDIR 2>/dev/null; do true; done
    [ "$lan_if" = "br0" ] || while iptables -t nat -D PREROUTING -i br0 -p tcp -j XRAY_REDIR 2>/dev/null; do true; done
    iptables -t nat -F XRAY_REDIR 2>/dev/null
    iptables -t nat -X XRAY_REDIR 2>/dev/null

    ipset destroy xray_bypass 2>/dev/null
    ipset destroy xray_exclude 2>/dev/null
    ipset destroy xray_remote 2>/dev/null
}

firewall_start() {
    local vpnc_en="0" vpnc_tp="" routing="" lan_if="" redir_port="" conf=""

    if command -v nvram >/dev/null 2>&1; then
        vpnc_en=$(nvram get vpnc_enable 2>/dev/null)
        vpnc_tp=$(nvram get vpnc_type 2>/dev/null)
        routing=$(nvram get vpnc_xray_routing 2>/dev/null)
        lan_if=$(nvram get lan_ifname 2>/dev/null)
    fi
    [ -n "$lan_if" ] || lan_if="br0"
    [ -n "$routing" ] || routing="1"

    firewall_stop

    # Only apply rules when Xray is active
    if ! is_running && [ "${vpnc_en}_${vpnc_tp}" != "1_6" ]; then
        return 0
    fi

    # 0 = Local SOCKS5/HTTP proxy only (no NAT REDIRECT)
    if [ "$routing" = "0" ]; then
        log "Routing mode: ProxyOnly (SOCKS5/HTTP only, transparent NAT disabled)."
        return 0
    fi

    if ! command -v ipset >/dev/null 2>&1; then
        log "ERROR: ipset utility not found; cannot enable transparent Xray routing."
        return 1
    fi

    for m in ip_set ip_set_hash_ip ip_set_hash_net xt_set nf_nat ipt_REDIRECT xt_REDIRECT; do
        modprobe -q "$m" 2>/dev/null || true
    done

    conf=$(find_config)
    redir_port=$(get_redir_port "$conf")

    ipset create xray_bypass hash:net -exist 2>/dev/null && ipset flush xray_bypass 2>/dev/null
    ipset create xray_exclude hash:net -exist 2>/dev/null && ipset flush xray_exclude 2>/dev/null
    ipset create xray_remote hash:net -exist 2>/dev/null && ipset flush xray_remote 2>/dev/null
    ipset create xray_domains hash:ip -exist 2>/dev/null
    ipset create xbox_direct hash:ip -exist 2>/dev/null
    ipset create xbox_vpn hash:ip -exist 2>/dev/null

    # Bypass private, reserved, WAN/LAN, and outbound VPS IPs
    for cidr in 0.0.0.0/8 10.0.0.0/8 100.64.0.0/10 127.0.0.0/8 169.254.0.0/16 172.16.0.0/12 192.168.0.0/16 224.0.0.0/4 240.0.0.0/4; do
        ipset add xray_bypass "$cidr" -exist 2>/dev/null
    done

    if command -v nvram >/dev/null 2>&1; then
        for var in wan_ipaddr wan0_ipaddr wanx_ipaddr lan_ipaddr; do
            local ip_val=$(nvram get "$var" 2>/dev/null)
            case "$ip_val" in
                ""|0.0.0.0) ;;
                [0-9]*.[0-9]*.[0-9]*.[0-9]*) ipset add xray_bypass "${ip_val}/32" -exist 2>/dev/null ;;
            esac
        done
    fi

    local srv="" srv_ip=""
    for srv in $(get_server_hosts "$conf"); do
        for srv_ip in $(resolve_ipv4 "$srv"); do
            ipset add xray_bypass "${srv_ip}/32" -exist 2>/dev/null
        done
    done

    load_ipset_cidrs xray_exclude "$EXCLUDE_NETWORK_LIST"

    iptables -t nat -N XRAY_REDIR 2>/dev/null || return 1
    iptables -t nat -A XRAY_REDIR -m set --match-set xray_bypass dst -j RETURN
    iptables -t nat -A XRAY_REDIR -m set --match-set xbox_direct dst -j RETURN 2>/dev/null || true
    iptables -t nat -A XRAY_REDIR -m set --match-set xray_exclude src -j RETURN

    if [ "$routing" = "2" ]; then
        iptables -t nat -A XRAY_REDIR -p tcp -j REDIRECT --to-ports "$redir_port"
        log "Transparent XRAY_REDIR enabled on $lan_if -> :$redir_port (mode: Full LAN TCP)."
    else
        load_ipset_cidrs xray_remote "$REMOTE_NETWORK_LIST"
        iptables -t nat -A XRAY_REDIR -p tcp -m set --match-set xray_remote dst -j REDIRECT --to-ports "$redir_port"
        iptables -t nat -A XRAY_REDIR -p tcp -m set --match-set xray_domains dst -j REDIRECT --to-ports "$redir_port"
        iptables -t nat -A XRAY_REDIR -p tcp -m set --match-set xbox_vpn dst -j REDIRECT --to-ports "$redir_port" 2>/dev/null || true
        log "Transparent XRAY_REDIR enabled on $lan_if -> :$redir_port (mode: Unblock lists/ipsets)."
    fi

    iptables -t nat -I PREROUTING -i "$lan_if" -p tcp -j XRAY_REDIR
}

start() {
    if is_running; then
        log "xray is already running (PID: $(cat "$PID_FILE" 2>/dev/null || pidof xray))"
        firewall_start
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

    export GOGC=25
    export GOMEMLIMIT=48MiB

    log "Starting xray using $bin with config $conf..."
    "$bin" run -c "$conf" > "$LOG_FILE" 2>&1 &
    local pid=$!
    echo "$pid" > "$PID_FILE"

    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        log "xray started successfully (PID: $pid)"
        firewall_start
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
    firewall_stop

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
    firewall)
        firewall_start
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|firewall|status}"
        exit 1
        ;;
esac
