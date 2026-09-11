#!/bin/sh
# Zapret 2 (nfqws2 + Lua) Padavan service script

NFQWS2_BIN="/usr/bin/nfqws2"
NFQWS2_BIN_OPT="/opt/bin/nfqws2"
NFQWS2_BIN_GIT="/tmp/nfqws2"
ETC_DIR="/etc"

[ -d "/etc_ro" -a -d "/etc/storage" ] && ETC_DIR="/etc/storage"

CONF_DIR="${ETC_DIR}/zapret2"
SHARED_CONF_DIR="${ETC_DIR}/zapret"
CONF_DIR_EXAMPLE="/usr/share/zapret2"
CONF_FILE="$CONF_DIR/config"
STRATEGY_FILE="$CONF_DIR/strategy"
PID_FILE="/var/run/zapret2.pid"
POST_SCRIPT="$CONF_DIR/post_script.sh"

DESYNC_MARK="0x40000000"
FILTER_MARK="0x10000000"

ISP_INTERFACE=
NFQUEUE_NUM=200
LOG_LEVEL=0
USER="nobody"
CLIENTS_ALLOWED=

log()
{
    [ -n "$*" ] || return
    echo "$@"
    local pid
    [ -f "$PID_FILE" ] && pid="[$(cat "$PID_FILE" 2>/dev/null)]"
    logger -t "zapret2$pid" "$@"
}

trim()
{
    awk '{gsub(/^ +| +$/,"")}1'
}

error()
{
    log "$@"
    exit 1
}

_get_if_default()
{
    ip -$1 route show default 2>/dev/null | grep via | sed -r 's/^.*default.*via.* dev ([^ ]+).*$/\1/' | head -n1
}

is_running()
{
    [ -f "$PID_FILE" ] && kill -0 $(cat "$PID_FILE" 2>/dev/null) 2>/dev/null
}

iptables_stop()
{
    local i
    for i in "" "6"; do
        [ "$i" = "6" ] && [ ! -d /proc/sys/net/ipv6 ] && continue
        ip${i}tables-restore -n 2>/dev/null <<EOR
*mangle
$(ip${i}tables-save -t mangle 2>/dev/null | sed -n "/\(queue-num $NFQUEUE_NUM --queue\|mark $DESYNC_MARK\/$DESYNC_MARK\|mark $FILTER_MARK\/$FILTER_MARK\)/{s/^-A/-D/p}")
COMMIT
EOR
    done
}

firewall_stop()
{
    iptables_stop
}

_mangle_rules()
{
    local i=$1
    local iface
    local wan_rules=""
    local client_rules=""

    for iface in $ISP_IF; do
        wan_rules="$wan_rules
-A POSTROUTING -o $iface -p tcp -m multiport --dports 80,443 -m connbytes --connbytes-dir original --connbytes-mode packets --connbytes 1:20 -m mark ! --mark $DESYNC_MARK/$DESYNC_MARK -j NFQUEUE --queue-num $NFQUEUE_NUM --queue-bypass
-A POSTROUTING -o $iface -p udp -m multiport --dports 443 -m connbytes --connbytes-dir original --connbytes-mode packets --connbytes 1:10 -m mark ! --mark $DESYNC_MARK/$DESYNC_MARK -j NFQUEUE --queue-num $NFQUEUE_NUM --queue-bypass
"
    done

    if [ -n "$CLIENTS_ALLOWED" ]; then
        for ip in $CLIENTS_ALLOWED; do
            client_rules="$client_rules
-A PREROUTING -s $ip -j MARK --set-xmark $FILTER_MARK/$FILTER_MARK
"
        done
        echo "$client_rules"
    fi

    echo "$wan_rules"
}

iptables_start()
{
    local i
    for i in "" "6"; do
        [ "$i" = "6" ] && [ ! -d /proc/sys/net/ipv6 ] && continue
        ip${i}tables-restore -n 2>/dev/null <<EOR
*mangle
$(_mangle_rules $i)
COMMIT
EOR
    done
}

firewall_start()
{
    firewall_stop
    iptables_start
}

# Stop Zapret 1 if running
stop_zapret1_if_running()
{
    if [ -f "/var/run/zapret.pid" ] || killall -0 nfqws 2>/dev/null; then
        log "Stopping conflicting Zapret 1 daemon..."
        /usr/bin/zapret.sh stop >/dev/null 2>&1
        killall -q -s 9 nfqws 2>/dev/null
    fi
}

start_service()
{
    [ -s "$NFQWS2_BIN" -a -x "$NFQWS2_BIN" ] || error "$NFQWS2_BIN: not found or invalid"
    if is_running; then
        echo "zapret2 is already running"
        return
    fi

    stop_zapret1_if_running

    # Hostlist substitution
    local hostlist_opts=""
    if [ -s "${SHARED_CONF_DIR}/user.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist=${SHARED_CONF_DIR}/user.list"
    elif [ -s "${CONF_DIR}/user.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist=${CONF_DIR}/user.list"
    fi

    if [ -s "${SHARED_CONF_DIR}/auto.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist-auto=${SHARED_CONF_DIR}/auto.list"
    elif [ -s "${CONF_DIR}/auto.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist-auto=${CONF_DIR}/auto.list"
    fi

    if [ -s "${SHARED_CONF_DIR}/exclude.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist-exclude=${SHARED_CONF_DIR}/exclude.list"
    elif [ -s "${CONF_DIR}/exclude.list" ]; then
        hostlist_opts="$hostlist_opts --hostlist-exclude=${CONF_DIR}/exclude.list"
    fi

    local strategy_args=""
    if [ -s "$STRATEGY_FILE" ]; then
        strategy_args=$(cat "$STRATEGY_FILE" | grep -v '^#' | tr '\n' ' ')
        strategy_args=$(echo "$strategy_args" | sed "s|<HOSTLIST>|$hostlist_opts|g" | sed "s|<HOSTLIST_NOAUTO>|$hostlist_opts|g")
    fi

    local debug_arg="--debug=0"
    [ "$LOG_LEVEL" = "1" ] && debug_arg="--debug=syslog"

    local base_blobs=""
    [ -f /usr/share/zapret2/fake/http_iana_org.bin ] && base_blobs="$base_blobs --blob=fake_default_http:@/usr/share/zapret2/fake/http_iana_org.bin"
    [ -f /usr/share/zapret2/fake/tls_clienthello_www_google_com.bin ] && base_blobs="$base_blobs --blob=fake_default_tls:@/usr/share/zapret2/fake/tls_clienthello_www_google_com.bin"
    [ -f /usr/share/zapret2/fake/quic_initial_www_google_com.bin ] && base_blobs="$base_blobs --blob=fake_default_quic:@/usr/share/zapret2/fake/quic_initial_www_google_com.bin"

    local lua_inits=""
    [ -f /usr/share/zapret2/lua/zapret-lib.lua ] && lua_inits="$lua_inits --lua-init=@/usr/share/zapret2/lua/zapret-lib.lua"
    [ -f /usr/share/zapret2/lua/zapret-antidpi.lua ] && lua_inits="$lua_inits --lua-init=@/usr/share/zapret2/lua/zapret-antidpi.lua"
    [ -f /usr/share/zapret2/lua/zapret-auto.lua ] && lua_inits="$lua_inits --lua-init=@/usr/share/zapret2/lua/zapret-auto.lua"

    local cmd="$NFQWS2_BIN --daemon --pidfile=$PID_FILE --qnum=$NFQUEUE_NUM --fwmark=$DESYNC_MARK --user=$USER $debug_arg $base_blobs $lua_inits $strategy_args"

    res=$($cmd 2>&1)
    if [ "$?" != "0" ]; then
        log "failed to start: $res"
        exit 1
    fi

    firewall_start
    log "started zapret2 successfully with strategy: $STRATEGY_FILE"

    if [ -x "$POST_SCRIPT" ]; then
        "$POST_SCRIPT" start >/dev/null 2>&1 &
    fi
}

stop_service()
{
    firewall_stop
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE" 2>/dev/null) 2>/dev/null
        rm -f "$PID_FILE"
    fi
    killall -q -s 15 $(basename "$NFQWS2_BIN") 2>/dev/null
    log "stopped"

    if [ -x "$POST_SCRIPT" ]; then
        "$POST_SCRIPT" stop >/dev/null 2>&1 &
    fi
}

reload_service()
{
    is_running || return
    firewall_start
    kill -HUP $(cat "$PID_FILE" 2>/dev/null) 2>/dev/null
}

# Execution Entry Point
[ -d "$CONF_DIR" ] || mkdir -p "$CONF_DIR" || exit 1
[ -d "$SHARED_CONF_DIR" ] || mkdir -p "$SHARED_CONF_DIR" || true

# Copy initial templates
if [ -d "$CONF_DIR_EXAMPLE" ]; then
    for f in "$CONF_DIR_EXAMPLE"/strategy*; do
        [ -f "$f" ] && [ ! -f "$CONF_DIR/$(basename "$f")" ] && cp -f "$f" "$CONF_DIR/"
    done
fi

# Ensure user/exclude/auto lists exist in shared location
for i in user.list exclude.list auto.list; do
    [ -f "${SHARED_CONF_DIR}/$i" ] || touch "${SHARED_CONF_DIR}/$i"
    # Symlink to zapret2 dir if not present
    [ -e "${CONF_DIR}/$i" ] || ln -sf "${SHARED_CONF_DIR}/$i" "${CONF_DIR}/$i"
done

[ -s "$CONF_FILE" ] && . "$CONF_FILE"

if [ -x "/usr/sbin/nvram" ]; then
    t="$(nvram get zapret2_iface)" && [ -n "$t" ] && ISP_INTERFACE="$t"
    t="$(nvram get zapret2_log)" && [ -n "$t" ] && LOG_LEVEL="$t"
    t="$(nvram get zapret2_strategy)" && [ -n "$t" ] && STRATEGY_FILE="${STRATEGY_FILE}$t"
    t="$(nvram get zapret2_clients_allowed)" && [ -n "$t" ] && CLIENTS_ALLOWED="$t"
    unset t
fi

CLIENTS_ALLOWED=$(echo $CLIENTS_ALLOWED | tr -s ',' ' ' | trim)

if [ -n "$ISP_INTERFACE" ]; then
    ISP_IF=$(echo "$ISP_INTERFACE" | tr -s ',' ' ' | trim | tr -s ' ' '\n' | sort -u)
else
    ISP_IF4=$(_get_if_default 4)
    ISP_IF6=$(_get_if_default 6)
    ISP_IF=$(printf "%s\n%s" "${ISP_IF4}" "${ISP_IF6}" | sort -u)
fi

case "$1" in
    start)
        start_service
    ;;
    stop)
        stop_service
    ;;
    restart)
        stop_service
        sleep 1
        start_service
    ;;
    reload)
        reload_service
    ;;
    status)
        if is_running; then
            echo "zapret2 is running (pid $(cat $PID_FILE 2>/dev/null))"
            exit 0
        else
            echo "zapret2 is stopped"
            exit 1
        fi
    ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|status}"
        exit 1
    ;;
esac
