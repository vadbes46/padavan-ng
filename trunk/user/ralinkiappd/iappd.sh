#!/bin/sh


is_enabled() {
	[ "$(nvram get rt_HT_80211R)" = "1" ] || \
	[ "$(nvram get wl_HT_80211R)" = "1" ] || \
	[ "$(nvram get rt_HT_80211KV)" = "1" ] || \
	[ "$(nvram get wl_HT_80211KV)" = "1" ]
}

start() {
	if ! is_enabled; then
		return 0
	fi

	pid=`pidof ralinkiappd`
	if [ -n "$pid" ]; then
		return 0
	fi

	if grep -q 'mt76x3_ap' /proc/modules ; then
		ralinkiappd -wi rai0 -d 0 &
		sysctl -wq net.ipv4.neigh.rai0.base_reachable_time_ms=10000
		sysctl -wq net.ipv4.neigh.rai0.delay_first_probe_time=1
	else
		if grep -q 'rai0' /proc/interrupts || grep -q 'rai0' /proc/net/dev ; then
			ralinkiappd -wi rai0 -wi ra0 -d 0 &
			sysctl -wq net.ipv4.neigh.rai0.base_reachable_time_ms=10000
			sysctl -wq net.ipv4.neigh.rai0.delay_first_probe_time=1
		elif grep -q 'rax0' /proc/interrupts || grep -q 'rax0' /proc/net/dev ; then
			ralinkiappd -wi rax0 -wi ra0 -d 0 &
			sysctl -wq net.ipv4.neigh.rax0.base_reachable_time_ms=10000
			sysctl -wq net.ipv4.neigh.rax0.delay_first_probe_time=1
		else
			ralinkiappd -wi ra0 -d 0 &
		fi
	fi
	sysctl -wq net.ipv4.neigh.br0.base_reachable_time_ms=10000
	sysctl -wq net.ipv4.neigh.br0.delay_first_probe_time=1
	sysctl -wq net.ipv4.neigh.eth2.base_reachable_time_ms=10000
	sysctl -wq net.ipv4.neigh.eth2.delay_first_probe_time=1
	sysctl -wq net.ipv4.neigh.ra0.base_reachable_time_ms=10000
	sysctl -wq net.ipv4.neigh.ra0.delay_first_probe_time=1
	iptables -C INPUT -i br0 -p tcp --dport 3517 -j ACCEPT 2>/dev/null || iptables -A INPUT -i br0 -p tcp --dport 3517 -j ACCEPT
	iptables -C INPUT -i br0 -p udp --dport 3517 -j ACCEPT 2>/dev/null || iptables -A INPUT -i br0 -p udp --dport 3517 -j ACCEPT 
}





stop() {
    pid=`pidof ralinkiappd`
    if [ "$pid" != "" ]; then
        killall -q ralinkiappd
	sleep 1
	killall -9 -q ralinkiappd 2>/dev/null
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
            start
            ;;

        *)
            echo $"Usage: $0 {start|stop|restart}"
esac
