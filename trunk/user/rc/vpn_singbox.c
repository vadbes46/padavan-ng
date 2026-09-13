/*
 * Sing-box VPN client integration for Padavan
 */

#include <stdio.h>
#include <stdlib.h>
#include "rc.h"

int
start_singbox_client(void)
{
	int ret = doSystem("/usr/bin/sing-box.sh %s", "start");
	if (ret != 0) {
		/* Try to find and run from mounted storage */
		ret = doSystem("sh -c 'for s in /media/*/sing-box/sing-box.sh; do [ -x \"$s\" ] && exec \"$s\" start; done; exit 1'");
	}
	nvram_set_int_temp("vpnc_state_t", (ret == 0) ? 1 : 0);
	return ret;
}

void
stop_singbox_client(void)
{
	doSystem("/usr/bin/sing-box.sh %s", "stop");
	doSystem("sh -c 'for s in /media/*/sing-box/sing-box.sh; do [ -x \"$s\" ] && exec \"$s\" stop; done' 2>/dev/null");
	nvram_set_int_temp("vpnc_state_t", 0);
}

void
restart_singbox_client(void)
{
	stop_singbox_client();
	start_singbox_client();
}
