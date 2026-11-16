/*
 * Xray VPN client integration for Padavan
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "rc.h"

int
start_xray_client(void)
{
	int had_domains = check_if_file_exist("/tmp/dnsmasq.xray.conf");
	int ret = doSystem("/usr/bin/xray.sh %s", "start");
	if (ret != 0) {
		/* Try to find and run from mounted storage */
		ret = doSystem("sh -c 'for s in /media/*/xray/xray.sh /media/*/*/xray/xray.sh; do [ -x \"$s\" ] && exec \"$s\" start; done; exit 1'");
	}
	nvram_set_int_temp("vpnc_state_t", (ret == 0) ? 1 : 0);
	if (ret == 0 && (had_domains || write_xray_dnsmasq_ipset() > 0))
		restart_dhcpd();
	return ret;
}

void
stop_xray_client(void)
{
	int had_domains = check_if_file_exist("/tmp/dnsmasq.xray.conf");
	doSystem("/usr/bin/xray.sh %s", "stop");
	doSystem("sh -c 'for s in /media/*/xray/xray.sh /media/*/*/xray/xray.sh; do [ -x \"$s\" ] && exec \"$s\" stop; done' 2>/dev/null");
	nvram_set_int_temp("vpnc_state_t", 0);
	if (had_domains && (nvram_get_int("vpnc_enable") == 0 || nvram_get_int("vpnc_type") != 6)) {
		unlink("/tmp/dnsmasq.xray.conf");
		restart_dhcpd();
	}
}

void
restart_xray_client(void)
{
	stop_xray_client();
	start_xray_client();
}
