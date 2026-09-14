<!DOCTYPE html>
<html>
<head>
<title><#Web_Title#> - <#menu6#></title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8">
<meta http-equiv="Pragma" content="no-cache">
<meta http-equiv="Expires" content="-1">

<link rel="shortcut icon" href="images/favicon.ico">
<link rel="icon" href="images/favicon.png">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/bootstrap.min.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/main.css">
<link rel="stylesheet" type="text/css" href="/bootstrap/css/engage.itoggle.css">

<script type="text/javascript" src="/jquery.js"></script>
<script type="text/javascript" src="/bootstrap/js/bootstrap.min.js"></script>
<script type="text/javascript" src="/bootstrap/js/engage.itoggle.min.js"></script>
<script type="text/javascript" src="/state.js"></script>
<script type="text/javascript" src="/general.js"></script>
<script type="text/javascript" src="/itoggle.js"></script>
<script type="text/javascript" src="/popup.js"></script>
<script>
var $j = jQuery.noConflict();

$j(document).ready(function() {
	init_itoggle('vpnc_enable', change_vpnc_enabled);

	$j("#tab_vpnc_cfg, #tab_vpnc_ssl").click(function(){
		var newHash = $j(this).attr('href').toLowerCase();
		showTab(newHash);
		return false;
	});
});

</script>
<script>

<% login_state_hook(); %>
<% openvpn_cli_cert_hook(); %>
<% net_update_vpnc_wg_state(); %>

lan_ipaddr_x = '<% nvram_get_x("", "lan_ipaddr"); %>';
lan_netmask_x = '<% nvram_get_x("", "lan_netmask"); %>';
fw_enable_x = '<% nvram_get_x("", "fw_enable_x"); %>';
vpnc_state_last = '<% nvram_get_x("", "vpnc_state_t"); %>';
ip6_service = '<% nvram_get_x("", "ip6_service"); %>';
vpnc_type = '<% nvram_get_x("", "vpnc_type"); %>';

function initial(){
	show_banner(0);
	show_menu(4, -1, 0);
	show_footer();

	if (!found_app_ovpn())
		document.form.vpnc_type.remove(2);
	else
	if (!support_ipv6() || ip6_service == ''){
		var o = document.form.vpnc_ov_prot;
		for (var i = 0; i < 4; i++) {
			o.remove(2);
		}
	}

	if (!found_app_wg())
		$j("#vpnc_type option[value='3']").remove();
	if (!found_app_awg())
		$j("#vpnc_type option[value='4']").remove();
	if (typeof found_app_singbox === 'function' ? !found_app_singbox() : false)
		$j("#vpnc_type option[value='5']").remove();
	if (typeof found_app_xray === 'function' ? !found_app_xray() : false)
		$j("#vpnc_type option[value='6']").remove();

	if (fw_enable_x == "0"){
		var o1 = document.form.vpnc_sfw;
		o1.remove(0);
		o1.remove(0);
	}

	change_vpnc_enabled();
	update_bin_status();

	showTab(getHash());

	load_body();
}

function update_vpnc_status(vpnc_state){
	this.vpnc_state_last = vpnc_state;
	if (vpnc_type == 3 || vpnc_type == 4 || vpnc_type == 5 || vpnc_type == 6) {
		showhide_div('col_vpnc_wg_state', (vpnc_state != 0 && document.form.vpnc_enable[0].checked) ? 1 : 0);
		if (vpnc_state == 2) {
			$("col_vpnc_wg_state").innerHTML = '<#Connecting#>';
			$('col_vpnc_wg_state').setAttribute('class', 'label label-warning');
		} else
		if (vpnc_state == 1) {
			$("col_vpnc_wg_state").innerHTML = '<#Connected#>';
			$('col_vpnc_wg_state').setAttribute('class', 'label label-success');
		}
	} else {
		showhide_div('col_vpnc_state', (vpnc_state != 0 && document.form.vpnc_enable[0].checked) ? 1 : 0);
	}
}

function applyRule(){
	if(validForm()){
		showLoading();

		document.form.action_mode.value = " Apply ";
		document.form.current_page.value = "/vpncli.asp";
		document.form.next_page.value = "";

		document.form.submit();
	}
}

function valid_rlan_subnet(oa, om){
	var ip4ra = parse_ipv4_addr(oa.value);
	var ip4rm = parse_ipv4_addr(om.value);
	if (ip4ra == null){
		alert(oa.value + " <#JS_validip#>");
		oa.focus();
		oa.select();
		return false;
	}
	if (ip4rm == null || isMask(om.value) <= 0){
		alert(om.value + " <#JS_validmask#>");
		om.focus();
		om.select();
		return false;
	}

	for (i=0;i<4;i++)
		ip4ra[i] = ip4ra[i] & ip4rm[i];
	var r_str = ip4ra[0] + '.' + ip4ra[1] + '.' + ip4ra[2] + '.' + ip4ra[3];

	if (matchSubnet2(oa.value, om.value, lan_ipaddr_x, lan_netmask_x)) {
		alert("Please set remote subnet not equal LAN subnet (" + r_str + ")!");
		oa.focus();
		oa.select();
		return false;
	}

	oa.value = r_str;

	return true;
}

function validForm(){
	if (!document.form.vpnc_enable[0].checked)
		return true;

	var mode = document.form.vpnc_type.value;

	if ((mode != "3") && (mode != "4") && (mode != "5") && (mode != "6") && document.form.vpnc_peer.value.length < 4) {
		alert("Remote host is invalid!");
		document.form.vpnc_peer.focus();
		return false;
	}

	if (mode != "5" && mode != "6") {
		if(!validate_string(document.form.vpnc_peer))
			return false;
	}

	if (mode == "5") {
		var sb_el = document.getElementById("scripts.singbox_config.json");
		if (sb_el && sb_el.value.trim().length > 0) {
			try { JSON.parse(sb_el.value); } catch(e) { alert("Invalid JSON syntax in Sing-box config: " + e.message); return false; }
		}
	}

	if (mode == "6") {
		var xr_el = document.getElementById("scripts.xray_config.json");
		if (xr_el && xr_el.value.trim().length > 0) {
			try { JSON.parse(xr_el.value); } catch(e) { alert("Invalid JSON syntax in Xray config: " + e.message); return false; }
		}
	}
	if (mode == "3" || mode == "4") {
		var pka = document.form.vpnc_wg_peer_keepalive.value.trim();
		if (pka.length > 0) {
			if (mode == "4" && pka.indexOf('-') !== -1) {
				var pka_parts = pka.split('-');
				var pk1 = Number(pka_parts[0]);
				var pk2 = Number(pka_parts[1]);
				if (pka_parts.length !== 2 || pka_parts[0] === "" || pka_parts[1] === "" || isNaN(pk1) || isNaN(pk2) || pk1 < 0 || pk1 > 65535 || pk2 < 0 || pk2 > 65535 || pk1 > pk2) {
					alert("Invalid range for PersistentKeepalive. Expected min-max in [0..65535]");
					document.form.vpnc_wg_peer_keepalive.focus();
					document.form.vpnc_wg_peer_keepalive.select();
					return false;
				}
			} else {
				if(!validate_range(document.form.vpnc_wg_peer_keepalive, 0, 65535))
					return false;
			}
		}

		if (document.form.vpnc_wg_if_addr.value==""){
			alert("<#JS_fieldblank#>");
			document.form.vpnc_wg_if_addr.focus();
			document.form.vpnc_wg_if_addr.select();
			return false;
		}

		if (document.form.vpnc_wg_if_private.value==""){
			alert("<#JS_fieldblank#>");
			document.form.vpnc_wg_if_private.focus();
			document.form.vpnc_wg_if_private.select();
			return false;
		}

		if (document.form.vpnc_wg_peer_public.value==""){
			alert("<#JS_fieldblank#>");
			document.form.vpnc_wg_peer_public.focus();
			document.form.vpnc_wg_peer_public.select();
			return false;
		}

		if (document.form.vpnc_wg_peer_endpoint.value==""){
			alert("<#JS_fieldblank#>");
			document.form.vpnc_wg_peer_endpoint.focus();
			document.form.vpnc_wg_peer_endpoint.select();
			return false;
		}

		if (document.form.vpnc_wg_peer_allowedips.value==""){
			alert("<#JS_fieldblank#>");
			document.form.vpnc_wg_peer_allowedips.focus();
			document.form.vpnc_wg_peer_allowedips.select();
			return false;
		}

		if(!validate_range(document.form.vpnc_wg_mtu, 1000, 1420)) {
			return false;
		}

		if(!validate_range(document.form.vpnc_wg_peer_port, 1, 65535))
			return false;

		if (mode == "4") {
			var awg_u16 = [
				document.form.vpnc_awg_jc,
				document.form.vpnc_awg_jmin,
				document.form.vpnc_awg_jmax,
				document.form.vpnc_awg_s1,
				document.form.vpnc_awg_s2,
				document.form.vpnc_awg_s3,
				document.form.vpnc_awg_s4
			];
			for (var i = 0; i < awg_u16.length; i++) {
				if (awg_u16[i].value.length > 0 && !validate_range(awg_u16[i], 0, 65535))
					return false;
			}

			var awg_u32 = [
				document.form.vpnc_awg_h1,
				document.form.vpnc_awg_h2,
				document.form.vpnc_awg_h3,
				document.form.vpnc_awg_h4
			];
			for (var j = 0; j < awg_u32.length; j++) {
				if (awg_u32[j].value.length > 0) {
					var val = awg_u32[j].value.trim();
					if (val.indexOf('-') !== -1) {
						var parts = val.split('-');
						var n1 = Number(parts[0]);
						var n2 = Number(parts[1]);
						if (parts.length !== 2 || parts[0] === "" || parts[1] === "" || isNaN(n1) || isNaN(n2) ||
						    n1 < 0 || n1 > 4294967295 || n2 < 0 || n2 > 4294967295 || n1 > n2) {
							alert("Invalid range for H" + (j+1) + ". Expected min-max in [0..4294967295]");
							awg_u32[j].focus();
							awg_u32[j].select();
							return false;
						}
					} else {
						if (!validate_range(awg_u32[j], 0, 4294967295))
							return false;
					}
				}
			}

			var i1_value = document.form.vpnc_awg_i1.value.trim();
			if (i1_value.length > 0 && !/^<.+>$/.test(i1_value)) {
				alert("Invalid I1 format. Expected '<b 0x...>' or packet tag format");
				document.form.vpnc_awg_i1.focus();
				document.form.vpnc_awg_i1.select();
				return false;
			}

			var hpk_val = document.form.vpnc_awg_hpk.value.trim();
			if (hpk_val.length > 0 && !/^[A-Za-z0-9+/]{42,43}={0,2}$/.test(hpk_val)) {
				alert("Invalid HeaderProtectionKey (must be 32 bytes Base64)");
				document.form.vpnc_awg_hpk.focus();
				document.form.vpnc_awg_hpk.select();
				return false;
			}

			var cpa_val = document.form.vpnc_awg_cpa.value.trim();
			if (cpa_val.length > 0) {
				if (cpa_val.indexOf('-') !== -1) {
					var cp_parts = cpa_val.split('-');
					var cp1 = Number(cp_parts[0]);
					var cp2 = Number(cp_parts[1]);
					if (cp_parts.length !== 2 || cp_parts[0] === "" || cp_parts[1] === "" || isNaN(cp1) || isNaN(cp2) || cp1 < 0 || cp1 > 65535 || cp2 < 0 || cp2 > 65535 || cp1 > cp2) {
						alert("Invalid range for ContentPaddingAddition. Expected min-max in [0..65535]");
						document.form.vpnc_awg_cpa.focus();
						document.form.vpnc_awg_cpa.select();
						return false;
					}
				} else {
					if (!validate_range(document.form.vpnc_awg_cpa, 0, 65535))
						return false;
				}
			}
		}
	}
	else if (mode == "2") {
		if(!validate_range(document.form.vpnc_ov_port, 1, 65535))
			return false;
	}
	else {
		if(!validate_range(document.form.vpnc_mtu, 1000, 1460))
			return false;
		if(!validate_range(document.form.vpnc_mru, 1000, 1460))
			return false;

		if (document.form.vpnc_rnet.value.length > 0)
			return valid_rlan_subnet(document.form.vpnc_rnet, document.form.vpnc_rmsk);
	}

	return true;
}

function done_validating(action){
}

function textarea_ovpn_enabled(v){
	inputCtrl(document.form['ovpncli.client.conf'], v);
	inputCtrl(document.form['ovpncli.ca.crt'], v);
	inputCtrl(document.form['ovpncli.client.crt'], v);
	inputCtrl(document.form['ovpncli.client.key'], v);
	inputCtrl(document.form['ovpncli.ta.key'], v);
}

function change_vpnc_enabled() {
	var v = document.form.vpnc_enable[0].checked;

	showhide_div('tbl_vpnc_config', v);
	showhide_div('tbl_vpnc_server', v);

	if (!v){
		showhide_div('tab_vpnc_ssl', 0);
		showhide_div('tbl_vpnc_route', 0);
		textarea_ovpn_enabled(0);
	}else{
		change_vpnc_type();
	}
}

function change_vpnc_type() {
	var mode = document.form.vpnc_type.value;
	var is_ov = (mode == "2") ? 1 : 0;
	var is_wg = (mode == "3") ? 1 : 0;
	var is_awg = (mode == "4") ? 1 : 0;
	var is_sb = (mode == "5") ? 1 : 0;
	var is_xray = (mode == "6") ? 1 : 0;
	var is_proxy_proto = (is_sb || is_xray) ? 1 : 0;
	var is_wg_family = (is_wg || is_awg) ? 1 : 0;
	vpnc_type = parseInt(mode, 10);

	showhide_div('row_vpnc_auth', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('row_vpnc_mppe', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('row_vpnc_pppd', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('row_vpnc_mtu', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('row_vpnc_mru', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('tbl_vpnc_route', !is_ov && !is_wg_family && !is_proxy_proto);
	showhide_div('tbl_vpnc_server', !is_proxy_proto);

	showhide_div('row_vpnc_ov_import', is_ov);
	showhide_div('row_vpnc_ov_port', is_ov);
	showhide_div('row_vpnc_ov_prot', is_ov);
	showhide_div('row_vpnc_ov_auth', is_ov);
	showhide_div('row_vpnc_ov_mdig', is_ov);
	showhide_div('row_vpnc_ov_ciph', is_ov);
	showhide_div('row_vpnc_ov_ncp_clist', is_ov);
	showhide_div('row_vpnc_ov_compress', is_ov);
	showhide_div('row_vpnc_ov_atls', is_ov);
	showhide_div('row_vpnc_ov_mode', is_ov);
	showhide_div('row_vpnc_ov_conf', is_ov);
	showhide_div('tab_vpnc_ssl', is_ov);
	showhide_div('certs_hint', (is_ov && !openvpn_cli_cert_found()) ? 1 : 0);

	textarea_ovpn_enabled(is_ov);

	showhide_div('row_vpnc_wg', is_wg_family);
	showhide_div('row_vpnc_awg', is_awg);
	showhide_div('row_vpnc_singbox', is_sb);
	showhide_div('row_vpnc_xray', is_xray);
	showhide_div('vpnc_peer_row', !is_wg_family && !is_proxy_proto);
	showhide_div('row_vpnc_exclude_network', is_wg_family);
	showhide_div('row_vpnc_remote_network', is_wg_family);

	$("vpnc_use_dns").innerHTML = "<#VPNC_PDNS#>";
	if (is_wg_family) $("vpnc_use_dns").innerHTML = "<#VPNC_WG_UseDNS#>";

	if (is_ov) {
		change_vpnc_ov_auth();
		change_vpnc_ov_atls();
		change_vpnc_ov_mode();
	}
	else {
		showhide_div('row_vpnc_ov_cnat', 0);

		showhide_div('row_vpnc_user', !is_wg_family && !is_proxy_proto);
		showhide_div('row_vpnc_pass', !is_wg_family && !is_proxy_proto);
	}

	update_vpnc_status(vpnc_state_last);
	update_bin_status();
}

function update_bin_status() {
	var sb_st = (typeof bin_status_singbox === 'function') ? bin_status_singbox() : 3;
	var xr_st = (typeof bin_status_xray === 'function') ? bin_status_xray() : 3;

	var sb_el = $("sb_bin_status");
	if (sb_el) {
		if (sb_st == 1) {
			sb_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_InROM#></span>';
			showhide_div('row_sb_bin_help', 0);
		} else if (sb_st == 2) {
			sb_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_OnEntware#></span>';
			showhide_div('row_sb_bin_help', 0);
		} else if (sb_st == 3) {
			sb_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_OnStorage#></span>';
			showhide_div('row_sb_bin_help', 0);
		} else {
			sb_el.innerHTML = '<span class="label label-important"><i class="icon-warning-sign icon-white"></i> <#VPNC_Bin_NotFound#></span>';
			showhide_div('row_sb_bin_help', 1);
		}
	}

	var xr_el = $("xray_bin_status");
	if (xr_el) {
		if (xr_st == 1) {
			xr_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_InROM#></span>';
			showhide_div('row_xray_bin_help', 0);
		} else if (xr_st == 2) {
			xr_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_OnEntware#></span>';
			showhide_div('row_xray_bin_help', 0);
		} else if (xr_st == 3) {
			xr_el.innerHTML = '<span class="label label-success"><i class="icon-ok icon-white"></i> <#VPNC_Bin_OnStorage#></span>';
			showhide_div('row_xray_bin_help', 0);
		} else {
			xr_el.innerHTML = '<span class="label label-important"><i class="icon-warning-sign icon-white"></i> <#VPNC_Bin_NotFound#></span>';
			showhide_div('row_xray_bin_help', 1);
		}
	}
}

function change_vpnc_ov_auth() {
	var v = (document.form.vpnc_ov_auth.value == "1") ? 1 : 0;

	showhide_div('row_vpnc_user', v);
	showhide_div('row_vpnc_pass', v);
	showhide_div('row_client_key', !v);
	showhide_div('row_client_crt', !v);
}

function change_vpnc_ov_atls() {
	var v = (document.form.vpnc_ov_atls.value != "0") ? 1 : 0;

	showhide_div('row_ta_key', v);
	inputCtrl(document.form['ovpncli.ta.key'], v);
}

function load_sb_template(type) {
	var ta = document.getElementById("scripts.singbox_config.json");
	if (!ta) return;
	if (ta.value.trim().length > 0 && !confirm("Replace existing configuration with template?"))
		return;
	if (type == 'hy2') {
		ta.value = JSON.stringify({
			"log": { "level": "warn", "timestamp": true },
			"dns": {
				"servers": [
					{ "tag": "remote-dns", "type": "https", "server": "1.1.1.1", "detour": "hy2-out" },
					{ "tag": "local-dns", "type": "local" }
				]
			},
			"inbounds": [
				{
					"type": "tun", "tag": "tun-in", "interface_name": "tun0",
					"address": [ "172.19.0.1/30" ],
					"auto_route": false, "strict_route": false, "stack": "gvisor"
				},
				{ "type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 1080 }
			],
			"outbounds": [
				{
					"type": "hysteria2", "tag": "hy2-out",
					"server": "vadbes46.online", "server_port": 443,
					"server_ports": [ "20000:50000" ], "hop_interval": "30s",
					"password": "vadbes46:a0f75ad5-0f7c-4740-bc72-d4d45b360562",
					"tls": { "enabled": true, "server_name": "vadbes46.online", "insecure": false },
					"obfs": { "type": "salamander", "password": "2334fa2e2fe01ed2341cd0b65e661497" }
				},
				{ "type": "direct", "tag": "direct" }
			],
			"route": {
				"auto_detect_interface": true,
				"default_domain_resolver": "local-dns",
				"rules": [
					{ "action": "hijack-dns", "protocol": "dns" },
					{ "ip_is_private": true, "outbound": "direct" }
				]
			}
		}, null, 2);
	} else {
		ta.value = JSON.stringify({
			"log": { "level": "warn", "timestamp": true },
			"dns": {
				"servers": [
					{ "tag": "remote-dns", "type": "https", "server": "1.1.1.1", "detour": "vless-out" },
					{ "tag": "local-dns", "type": "local" }
				]
			},
			"inbounds": [
				{
					"type": "tun", "tag": "tun-in", "interface_name": "tun0",
					"address": [ "172.19.0.1/30" ],
					"auto_route": false, "strict_route": false, "stack": "gvisor"
				},
				{ "type": "mixed", "tag": "mixed-in", "listen": "0.0.0.0", "listen_port": 1080 }
			],
			"outbounds": [
				{
					"type": "vless", "tag": "vless-out",
					"server": "vadbes46.online", "server_port": 443,
					"uuid": "a0f75ad5-0f7c-4740-bc72-d4d45b360562",
					"tls": { "enabled": true, "server_name": "vadbes46.online", "insecure": false, "utls": { "enabled": true, "fingerprint": "chrome" } },
					"transport": { "type": "ws", "path": "/ray-ws", "headers": { "Host": "vadbes46.online" } }
				},
				{ "type": "direct", "tag": "direct" }
			],
			"route": {
				"auto_detect_interface": true,
				"default_domain_resolver": "local-dns",
				"rules": [
					{ "action": "hijack-dns", "protocol": "dns" },
					{ "ip_is_private": true, "outbound": "direct" }
				]
			}
		}, null, 2);
	}
}

function load_xray_template() {
	var ta = document.getElementById("scripts.xray_config.json");
	if (!ta) return;
	if (ta.value.trim().length > 0 && !confirm("Replace existing configuration with template?"))
		return;
	ta.value = JSON.stringify({
		"log": { "loglevel": "warning" },
		"inbounds": [
			{
				"port": 1080, "listen": "0.0.0.0", "protocol": "socks",
				"settings": { "auth": "noauth", "udp": true },
				"sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
			},
			{
				"port": 1081, "listen": "0.0.0.0", "protocol": "http",
				"settings": {},
				"sniffing": { "enabled": true, "destOverride": ["http", "tls"] }
			},
			{
				"port": 1082, "listen": "0.0.0.0", "protocol": "dokodemo-door",
				"settings": { "network": "tcp,udp", "followRedirect": true },
				"sniffing": { "enabled": true, "destOverride": ["http", "tls", "quic"] }
			}
		],
		"outbounds": [
			{
				"tag": "proxy", "protocol": "vless",
				"settings": {
					"vnext": [{
						"address": "vadbes46.online", "port": 443,
						"users": [{ "id": "a0f75ad5-0f7c-4740-bc72-d4d45b360562", "encryption": "none" }]
					}]
				},
				"streamSettings": {
					"network": "xhttp", "security": "tls",
					"tlsSettings": { "serverName": "vadbes46.online", "fingerprint": "firefox" },
					"xhttpSettings": { "path": "/ray-xhttp", "host": "vadbes46.online", "mode": "auto" }
				}
			},
			{ "tag": "direct", "protocol": "freedom" },
			{ "tag": "block", "protocol": "blackhole" }
		],
		"routing": {
			"domainStrategy": "AsIs",
			"rules": [{ "type": "field", "ip": ["geoip:private"], "outboundTag": "direct" }]
		}
	}, null, 2);
}

function ov_conf_import() {
	const fileInput = document.getElementById('ov_fileInput');
	const file = fileInput.files[0];

	if (!file) {
		alert('Select file');
		return;
	}
	if (file.size > 65536) {
	alert("File is too big");
		return;
	}

	const reader = new FileReader();
	reader.onload = function(e) {
		const content = e.target.result;
		const lines = content.split(/\r?\n/);

		let settings = {};
		let certBlocks = {};
		let currentBlock = null;
		let blockContent = [];
		let remoteSet = false;

		document.querySelector('[name="vpnc_peer"]').value = '';
		document.querySelector('[name="vpnc_ov_port"]').value = '1194';
		document.querySelector('[name="vpnc_ov_prot"]').value = 0;
		document.querySelector('[name="vpnc_ov_mode"]').value = 1;
		document.querySelector('[name="vpnc_ov_auth"]').value = 0;
		document.querySelector('[name="vpnc_user"]').value = '';
		document.querySelector('[name="vpnc_pass"]').value = '';
		document.querySelector('[name="vpnc_ov_mdig"]').value = 1;
		document.querySelector('[name="vpnc_ov_ciph"]').value = 3;
		document.querySelector('[name="vpnc_ov_ncp_clist"]').value = '';
		document.querySelector('[name="vpnc_ov_compress"]').value = 0;
		document.querySelector('[name="vpnc_ov_atls"]').value = 0;
		document.querySelector('[name="ovpncli.ca.crt"]').value = '';
		document.querySelector('[name="ovpncli.client.crt"]').value = '';
		document.querySelector('[name="ovpncli.client.key"]').value = '';
		document.querySelector('[name="ovpncli.ta.key"]').value = '';

		lines.forEach(line => {
			let trimmed = line.trim();

			// блок сертификатов
			if (/^<\w+>/.test(trimmed)) {
				currentBlock = trimmed.replace(/[<>]/g, '').toLowerCase();
				blockContent = [];
				return;
			}
			if (/^<\/\w+>/.test(trimmed)) {
				certBlocks[currentBlock] = blockContent.join("\n");
				currentBlock = null;
				return;
			}
			if (currentBlock) {
				blockContent.push(line);
				return;
			}

			// комментарии/пустые
			if (!trimmed || trimmed.startsWith('#') || trimmed.startsWith(';')) return;

			const parts = trimmed.split(/\s+/);
			const key = parts[0].toLowerCase();
			const value = parts.slice(1).join(' ');

			if (key === 'remote') {
				if (!remoteSet) {
					settings[key] = value;
					remoteSet = true;
				}
				return;
			}

			settings[key] = value;
		});

		// ===== Заполнение формы =====
		if (settings['remote']) {
			const parts = settings['remote'].split(/\s+/);
			const host = parts[0] || '';
			const port = parts[1] || '';
			let protoHint = parts[2] ? parts[2].toLowerCase() : (settings['proto'] || 'udp').toLowerCase();

			document.querySelector('[name="vpnc_peer"]').value = host;
			if (port) document.querySelector('[name="vpnc_ov_port"]').value = port;

			// IPv6?
			let isIPv6 = /\[.*\]/.test(host) || (host.includes(':') && !host.match(/^\d+\.\d+\.\d+\.\d+$/));

			// Прямое определение по protoHint
			let protValue;
			switch (protoHint) {
				case 'udp4': protValue = 0; break;
				case 'tcp4': protValue = 1; break;
				case 'udp6': protValue = 2; break;
				case 'tcp6': protValue = 3; break;
				case 'tcp':  protValue = isIPv6 ? 3 : 1; break;
				case 'udp':  protValue = isIPv6 ? 2 : 0; break;
				default:     protValue = isIPv6 ? 2 : 0; break; // udp по умолчанию
			}

			document.querySelector('[name="vpnc_ov_prot"]').value = protValue;
		}

		// dev
		if (settings['dev']) {
			let dev = settings['dev'].toLowerCase();
			document.querySelector('[name="vpnc_ov_mode"]').value = (dev === 'tap') ? 0 : 1;
		}

		// auth
		if (settings['auth']) {
			const authMap = {
				'md5': 0, 'sha1': 1, 'sha224': 2,
				'sha256': 3, 'sha384': 4, 'sha512': 5
			};
			let val = settings['auth'].toLowerCase();
			if (authMap.hasOwnProperty(val))
				document.querySelector('[name="vpnc_ov_mdig"]').value = authMap[val];
		}

		// cipher
		if (settings['cipher']) {
			const cipherMap = {
				'none': 0, 'des-cbc': 1, 'des-ede-cbc': 2, 'bf-cbc': 3,
				'aes-128-cbc': 4, 'aes-192-cbc': 5, 'des-ede3-cbc': 6,
				'desx-cbc': 7, 'aes-256-cbc': 8, 'camellia-128-cbc': 9,
				'camellia-192-cbc': 10, 'camellia-256-cbc': 11,
				'aes-128-gcm': 12, 'aes-192-gcm': 13, 'aes-256-gcm': 14,
				'chacha20-poly1305': 15
			};
			let val = settings['cipher'].toLowerCase();
			if (cipherMap.hasOwnProperty(val))
				document.querySelector('[name="vpnc_ov_ciph"]').value = cipherMap[val];
		}

		// data-ciphers
		if (settings['data-ciphers']) {
			document.querySelector('[name="vpnc_ov_ncp_clist"]').value = settings['data-ciphers'];
		} else if (settings['cipher']) {
			document.querySelector('[name="vpnc_ov_ncp_clist"]').value = settings['cipher'];
		}

		// compression
		if (settings['comp-lzo']) {
			document.querySelector('[name="vpnc_ov_compress"]').value =
				settings['comp-lzo'] === 'no' ? 1 : 2;
			}
		if (settings['lz4-v2']) {
			document.querySelector('[name="vpnc_ov_compress"]').value = 4;
		}
		if (settings['compress']) {
			if (settings['compress'].includes('lz4-v2'))
				document.querySelector('[name="vpnc_ov_compress"]').value = 4;
			else if (settings['compress'].includes('lz4'))
				document.querySelector('[name="vpnc_ov_compress"]').value = 3;
		}

		// auth-user-pass
		if (settings['auth-user-pass'] != undefined) {
			document.querySelector('[name="vpnc_ov_auth"]').value = 1;
		}

		// TLS-Auth / TLS-Crypt
		if (certBlocks['ta']) document.querySelector('[name="vpnc_ov_atls"]').value = 1;
		if (certBlocks['tc']) document.querySelector('[name="vpnc_ov_atls"]').value = 2;
		if (certBlocks['ctc2']) document.querySelector('[name="vpnc_ov_atls"]').value = 3;

		// ===== Заполнение сертификатов =====
		if (certBlocks['ca']) document.querySelector('[name="ovpncli.ca.crt"]').value = certBlocks['ca'];
		if (certBlocks['cert']) document.querySelector('[name="ovpncli.client.crt"]').value = certBlocks['cert'];
		if (certBlocks['key']) document.querySelector('[name="ovpncli.client.key"]').value = certBlocks['key'];
		if (certBlocks['ta']) document.querySelector('[name="ovpncli.ta.key"]').value = certBlocks['ta'];
		// тут непонятно, не протестировано
		if (certBlocks['tc']) document.querySelector('[name="ovpncli.ta.key"]').value = certBlocks['tc'];
		if (certBlocks['ctc2']) document.querySelector('[name="ovpncli.ta.key"]').value = certBlocks['ctc2'];

		change_vpnc_ov_auth();
		change_vpnc_ov_atls();
		change_vpnc_ov_mode();
	};
	reader.readAsText(file);
}

var arrHashes = ["cfg", "ssl"];

function showTab(curHash){
	var obj = $('tab_vpnc_'+curHash.slice(1));
	if (obj == null || obj.style.display == 'none')
		curHash = '#cfg';
	for(var i = 0; i < arrHashes.length; i++){
		if(curHash == ('#'+arrHashes[i])){
			$j('#tab_vpnc_'+arrHashes[i]).parents('li').addClass('active');
			$j('#wnd_vpnc_'+arrHashes[i]).show();
		}else{
			$j('#wnd_vpnc_'+arrHashes[i]).hide();
			$j('#tab_vpnc_'+arrHashes[i]).parents('li').removeClass('active');
		}
	}
	window.location.hash = curHash;
}

function getHash(){
	var curHash = window.location.hash.toLowerCase();
	for(var i = 0; i < arrHashes.length; i++){
		if(curHash == ('#'+arrHashes[i]))
			return curHash;
	}
	return ('#'+arrHashes[0]);
}

function get_wg_action_mode() {
	return (document.form.vpnc_type.value == "4") ? ' awg_action ' : ' wg_action ';
}

function wg_pubkey(){
	if (!login_safe())
		return false;

	if (document.form.vpnc_wg_if_private.value.length != 44) {
		document.form.vpnc_wg_if_public.value = "";
		return;
	}

	$j.post('/apply.cgi',
	{
		'action_mode': get_wg_action_mode(),
		'action': 'pubkey',
		'privkey': document.form.vpnc_wg_if_private.value
	},
	function(response){
		document.form.vpnc_wg_if_public.value = response;
	});
}

function wg_genkey(){
	if (!login_safe())
		return false;

	$j.post('/apply.cgi',
	{
		'action_mode': get_wg_action_mode(),
		'action': 'genkey'
	},
	function(response){
		document.form.vpnc_wg_if_private.value = response;

		$j.post('/apply.cgi',
		{
			'action_mode': get_wg_action_mode(),
			'action': 'pubkey',
			'privkey': document.form.vpnc_wg_if_private.value
		},
		function(response){
			document.form.vpnc_wg_if_public.value = response;
		});
	});
}

function wg_genpsk(){
	if (!login_safe())
		return false;

	$j.post('/apply.cgi',
	{
		'action_mode': get_wg_action_mode(),
		'action': 'genpsk'
	},
	function(response){
		document.form.vpnc_wg_if_preshared.value = response;
	});
}

function is_range(o, e) {
	e = e || event;
	if (is_control_key(e))
		return true;
	var keyPressed = e.keyCode ? e.keyCode : e.which;
	if (keyPressed == 0)
		return true;
	if ((keyPressed >= 48 && keyPressed <= 57) || keyPressed == 45)
		return true;
	return false;
}

function extract_awg_config_from_json(json) {
	var iniConfig = "";
	var container = null;
	if (json.containers && json.containers.length > 0) {
		container = json.containers.find(function(c) { return c.container === "amnezia-awg2"; }) ||
		            json.containers.find(function(c) { return c.container === "amnezia-awg"; }) ||
		            json.containers.find(function(c) { return c.container === json.defaultContainer; }) ||
		            json.containers[0];
	}

	if (container) {
		var awg = container.awg || container["amnezia-awg"] || container["amnezia-awg2"] || container;
		if (awg.last_config) {
			try {
				var parsedLast = JSON.parse(awg.last_config);
				if (parsedLast.config)
					iniConfig = parsedLast.config;
			} catch(e) {
				iniConfig = awg.last_config;
			}
		}
	}

	if (!iniConfig && json.last_config) {
		try {
			var parsedLast = JSON.parse(json.last_config);
			if (parsedLast.config)
				iniConfig = parsedLast.config;
		} catch(e) {
			iniConfig = json.last_config;
		}
	}

	if (!iniConfig && container) {
		var awg = container.awg || container["amnezia-awg"] || container["amnezia-awg2"] || container;
		var lines = ["[Interface]"];
		if (awg.client_ip || awg.subnet_address) lines.push("Address = " + (awg.client_ip || awg.subnet_address));
		if (awg.client_priv_key) lines.push("PrivateKey = " + awg.client_priv_key);
		if (json.dns1) lines.push("DNS = " + json.dns1 + (json.dns2 ? ", " + json.dns2 : ""));
		if (awg.Jc) lines.push("Jc = " + awg.Jc);
		if (awg.Jmin) lines.push("Jmin = " + awg.Jmin);
		if (awg.Jmax) lines.push("Jmax = " + awg.Jmax);
		if (awg.S1) lines.push("S1 = " + awg.S1);
		if (awg.S2) lines.push("S2 = " + awg.S2);
		if (awg.S3) lines.push("S3 = " + awg.S3);
		if (awg.S4) lines.push("S4 = " + awg.S4);
		if (awg.H1) lines.push("H1 = " + awg.H1);
		if (awg.H2) lines.push("H2 = " + awg.H2);
		if (awg.H3) lines.push("H3 = " + awg.H3);
		if (awg.H4) lines.push("H4 = " + awg.H4);
		if (awg.I1) lines.push("I1 = " + awg.I1);
		if (awg.header_protection_key || awg.HeaderProtectionKey) lines.push("HeaderProtectionKey = " + (awg.header_protection_key || awg.HeaderProtectionKey));
		if (awg.content_padding_addition || awg.ContentPaddingAddition) lines.push("ContentPaddingAddition = " + (awg.content_padding_addition || awg.ContentPaddingAddition));
		lines.push("");
		lines.push("[Peer]");
		if (awg.server_pub_key) lines.push("PublicKey = " + awg.server_pub_key);
		if (json.hostName && awg.port) lines.push("Endpoint = " + json.hostName + ":" + awg.port);
		if (awg.allowed_ips) lines.push("AllowedIPs = " + (Array.isArray(awg.allowed_ips) ? awg.allowed_ips.join(", ") : awg.allowed_ips));
		if (awg.persistent_keep_alive) lines.push("PersistentKeepalive = " + awg.persistent_keep_alive);
		iniConfig = lines.join("\n");
	}

	if (iniConfig) {
		if (json.dns1) iniConfig = iniConfig.replace(/\$PRIMARY_DNS/g, json.dns1);
		if (json.dns2) iniConfig = iniConfig.replace(/\$SECONDARY_DNS/g, json.dns2);
		iniConfig = iniConfig.replace(/,\s*\$SECONDARY_DNS/g, "").replace(/\$SECONDARY_DNS/g, "");
		return iniConfig;
	}

	return "";
}

function wg_conf_import() {
	const fileInput = document.getElementById('wg_fileInput');
	const file = fileInput.files[0];

	if (!file) {
		alert('Select file');
		return;
	}

	if (fileInput.files[0].size > 65536) {
		alert("File is too big (max 64KB)");
		return;
	}

	const reader = new FileReader();

	reader.onload = async function(e) {
		var content = e.target.result;
		if (typeof content !== "string")
			return;

		content = content.trim();

		// Check if content contains Amnezia vpn:// URI
		var vpnMatch = content.match(/vpn:\/\/[A-Za-z0-9_\-\+/=]+/);
		if (vpnMatch) {
			try {
				var b64 = vpnMatch[0].substring(6).trim();
				b64 = b64.replace(/-/g, '+').replace(/_/g, '/');
				while (b64.length % 4) b64 += '=';

				var binary = atob(b64);
				var bytes = new Uint8Array(binary.length);
				for (var k = 0; k < binary.length; k++) {
					bytes[k] = binary.charCodeAt(k);
				}
				var compressed = bytes.subarray(4);

				var decompressedText = null;
				var fmts = ['deflate', 'deflate-raw'];
				for (var f = 0; f < fmts.length; f++) {
					try {
						var ds = new DecompressionStream(fmts[f]);
						var stream = new Response(compressed).body.pipeThrough(ds);
						decompressedText = await new Response(stream).text();
						if (decompressedText)
							break;
					} catch (err) {}
				}

				if (decompressedText) {
					var json = JSON.parse(decompressedText);
					var extracted = extract_awg_config_from_json(json);
					if (extracted)
						content = extracted;
				}
			} catch (err) {
				console.error("Failed to parse vpn:// URI:", err);
				alert("Failed to parse Amnezia vpn:// configuration: " + (err.message || err));
				return;
			}
		} else if (content.startsWith("{")) {
			try {
				var json = JSON.parse(content);
				var extracted = extract_awg_config_from_json(json);
				if (extracted)
					content = extracted;
			} catch (err) {}
		}

		var iface = {};
		var peer = {};
		var section = "";

		const lines = content.split(/\r?\n/);
		lines.forEach(line => {
			line = line.trim();
			if (!line || line.startsWith('#') || line.startsWith(';'))
				return;

			if (line.startsWith('[') && line.endsWith(']')) {
				section = line.substring(1, line.length - 1).trim().toLowerCase();
				return;
			}

			const separatorIndex = line.indexOf('=');
			if (separatorIndex <= 0)
				return;

			const key = line.substring(0, separatorIndex).trim().toLowerCase();
			let value = line.substring(separatorIndex + 1).trim();
			const hashIndex = value.indexOf('#');
			const semicolonIndex = value.indexOf(';');
			let commentIndex = -1;
			if (hashIndex >= 0)
				commentIndex = hashIndex;
			if (semicolonIndex >= 0 && (commentIndex < 0 || semicolonIndex < commentIndex))
				commentIndex = semicolonIndex;
			if (commentIndex >= 0)
				value = value.substring(0, commentIndex).trim();

			if (!value)
				return;

			if (section == "peer") {
				if (typeof peer[key] === "undefined")
					peer[key] = value;
			} else {
				iface[key] = value;
			}
		});

		document.form.vpnc_wg_if_addr.value = "";
		document.form.vpnc_wg_if_private.value = "";
		document.form.vpnc_wg_if_preshared.value = "";
		document.form.vpnc_wg_mtu.value = "<% nvram_get_x("", "vpnc_wg_mtu"); %>";
		document.form.vpnc_wg_peer_public.value = "";
		document.form.vpnc_wg_peer_endpoint.value = "";
		document.form.vpnc_wg_peer_port.value = "";
		document.form.vpnc_wg_peer_keepalive.value = "";
		document.form.vpnc_wg_peer_allowedips.value = "";
		document.form.vpnc_wg_if_dns.value = "";
		document.form.vpnc_awg_jc.value = "";
		document.form.vpnc_awg_jmin.value = "";
		document.form.vpnc_awg_jmax.value = "";
		document.form.vpnc_awg_s1.value = "";
		document.form.vpnc_awg_s2.value = "";
		document.form.vpnc_awg_s3.value = "";
		document.form.vpnc_awg_s4.value = "";
		document.form.vpnc_awg_h1.value = "";
		document.form.vpnc_awg_h2.value = "";
		document.form.vpnc_awg_h3.value = "";
		document.form.vpnc_awg_h4.value = "";
		document.form.vpnc_awg_i1.value = "";
		document.form.vpnc_awg_hpk.value = "";
		document.form.vpnc_awg_cpa.value = "";

		if (iface.address) document.form.vpnc_wg_if_addr.value = iface.address;
		if (iface.privatekey) document.form.vpnc_wg_if_private.value = iface.privatekey;
		if (peer.presharedkey) document.form.vpnc_wg_if_preshared.value = peer.presharedkey;
		if (iface.mtu) document.form.vpnc_wg_mtu.value = iface.mtu;
		if (peer.publickey) document.form.vpnc_wg_peer_public.value = peer.publickey;
		if (peer.endpoint) {
			if (peer.endpoint.startsWith('[')) {
				const ipv6Separator = peer.endpoint.lastIndexOf(']:');
				if (ipv6Separator > 0) {
					document.form.vpnc_wg_peer_endpoint.value = peer.endpoint.substring(0, ipv6Separator + 1);
					document.form.vpnc_wg_peer_port.value = peer.endpoint.substring(ipv6Separator + 2);
				} else {
					document.form.vpnc_wg_peer_endpoint.value = peer.endpoint;
				}
			} else {
				const separatorIndex = peer.endpoint.lastIndexOf(':');
				if (separatorIndex > 0 && peer.endpoint.indexOf(':') == separatorIndex) {
					document.form.vpnc_wg_peer_endpoint.value = peer.endpoint.substring(0, separatorIndex);
					document.form.vpnc_wg_peer_port.value = peer.endpoint.substring(separatorIndex + 1);
				} else {
					document.form.vpnc_wg_peer_endpoint.value = peer.endpoint;
				}
			}
		}
		if (peer.persistentkeepalive) document.form.vpnc_wg_peer_keepalive.value = peer.persistentkeepalive;
		if (peer.allowedips) document.form.vpnc_wg_peer_allowedips.value = peer.allowedips;
		if (iface.dns) document.form.vpnc_wg_if_dns.value = iface.dns;
		if (iface.jc) document.form.vpnc_awg_jc.value = iface.jc;
		if (iface.jmin) document.form.vpnc_awg_jmin.value = iface.jmin;
		if (iface.jmax) document.form.vpnc_awg_jmax.value = iface.jmax;
		if (iface.s1) document.form.vpnc_awg_s1.value = iface.s1;
		if (iface.s2) document.form.vpnc_awg_s2.value = iface.s2;
		if (iface.s3) document.form.vpnc_awg_s3.value = iface.s3;
		if (iface.s4) document.form.vpnc_awg_s4.value = iface.s4;
		if (iface.h1) document.form.vpnc_awg_h1.value = iface.h1;
		if (iface.h2) document.form.vpnc_awg_h2.value = iface.h2;
		if (iface.h3) document.form.vpnc_awg_h3.value = iface.h3;
		if (iface.h4) document.form.vpnc_awg_h4.value = iface.h4;
		if (iface.i1) document.form.vpnc_awg_i1.value = iface.i1;
		if (iface.headerprotectionkey) document.form.vpnc_awg_hpk.value = iface.headerprotectionkey;
		if (iface.contentpaddingaddition) document.form.vpnc_awg_cpa.value = iface.contentpaddingaddition;

		var has_awg = iface.jc || iface.jmin || iface.jmax || iface.s1 || iface.s2 || iface.s3 || iface.s4 || iface.h1 || iface.h2 || iface.h3 || iface.h4 || iface.i1 || iface.headerprotectionkey || iface.contentpaddingaddition;
		if (has_awg && document.form.vpnc_type.value != "4") {
			document.form.vpnc_type.value = "4";
			change_vpnc_type();
		}

		try {
			wg_pubkey();
		} catch (err) {
			if (window.console && console.warn)
				console.warn("Failed to generate public key during import:", err);
		}
	};
	reader.readAsText(file);
}

var current_editor_target = null;

function open_modal_editor(fieldName, title) {
	current_editor_target = document.form[fieldName];
	if (!current_editor_target)
		return;

	$j('#modal_editor_title').text(title || '<#CTL_modify#>');
	$j('#modal_editor_content').val(current_editor_target.value);
	$j('#modal_editor_msg').text('');
	update_modal_editor_stats();
	$j('#modal_text_editor').modal('show');
}

function update_modal_editor_stats() {
	var val = $j('#modal_editor_content').val() || '';
	var lines = 0;
	if (val.length > 0) {
		var match = val.match(/\n/g);
		lines = match ? match.length + 1 : 1;
	}
	var kb = (val.length / 1024).toFixed(1);
	$j('#modal_editor_stats').text(lines + ' lines | ' + kb + ' KB');
}

function modal_editor_apply() {
	if (current_editor_target) {
		current_editor_target.value = $j('#modal_editor_content').val();
	}
	$j('#modal_text_editor').modal('hide');
}

function modal_editor_apply_and_save() {
	modal_editor_apply();
	applyRule();
}

function modal_editor_clean() {
	var val = $j('#modal_editor_content').val();
	var lines = val.split(/\r\n|\r|\n/);
	var filtered = [];
	for (var i = 0; i < lines.length; i++) {
		var t = lines[i].trim();
		if (t.length > 0)
			filtered.push(t);
	}
	$j('#modal_editor_content').val(filtered.join('\n'));
	update_modal_editor_stats();
}

function modal_editor_dedup() {
	var val = $j('#modal_editor_content').val();
	var lines = val.split(/\r\n|\r|\n/);
	var seen = {};
	var unique = [];
	for (var i = 0; i < lines.length; i++) {
		var t = lines[i].trim();
		if (t.length > 0 && !seen[t]) {
			seen[t] = true;
			unique.push(t);
		}
	}
	$j('#modal_editor_content').val(unique.join('\n'));
	update_modal_editor_stats();
}

function modal_editor_sort() {
	var val = $j('#modal_editor_content').val();
	var lines = val.split(/\r\n|\r|\n/);
	var filtered = [];
	for (var i = 0; i < lines.length; i++) {
		var t = lines[i].trim();
		if (t.length > 0)
			filtered.push(t);
	}
	filtered.sort();
	$j('#modal_editor_content').val(filtered.join('\n'));
	update_modal_editor_stats();
}

function modal_editor_copy() {
	var el = document.getElementById('modal_editor_content');
	if (!el) return;
	el.focus();
	el.select();
	try {
		document.execCommand('copy');
		$j('#modal_editor_msg').text('<#CTL_copy#> OK').show().fadeOut(2500);
	} catch(e) {
		alert('Copy failed');
	}
}

function modal_editor_load_file(input) {
	if (input.files && input.files[0]) {
		var reader = new FileReader();
		reader.onload = function(e) {
			$j('#modal_editor_content').val(e.target.result);
			update_modal_editor_stats();
		};
		reader.readAsText(input.files[0]);
	}
	input.value = '';
}

</script>

<style>
    .caption-bold {
        font-weight: bold;
    }
    .hint-nowrap {
        color: #888;
        white-space: nowrap;
    }
    .modal-editor {
        width: 86% !important;
        max-width: 960px !important;
        left: 50% !important;
        margin-left: -43% !important;
        top: 4% !important;
        margin-top: 0 !important;
    }
    @media (min-width: 1120px) {
        .modal-editor {
            width: 960px !important;
            margin-left: -480px !important;
        }
    }
    .modal-editor .modal-body {
        max-height: calc(82vh - 140px) !important;
        padding: 10px 15px !important;
    }
    .modal-editor textarea {
        width: 100% !important;
        height: 52vh !important;
        min-height: 380px !important;
        box-sizing: border-box !important;
        font-family: 'Courier New', monospace !important;
        font-size: 12px !important;
        line-height: 1.4 !important;
        resize: vertical !important;
    }
</style>

</head>

<body onload="initial();" onunload="unload_body();">
<script>
    if(get_ap_mode()){
        alert("<#page_not_support_mode_hint#>");
        location.href = "/as.asp";
    }
</script>

<div class="wrapper">
    <div class="container-fluid" style="padding-right: 0px">
        <div class="row-fluid">
            <div class="span3"><center><div id="logo"></div></center></div>
            <div class="span9" >
                <div id="TopBanner"></div>
            </div>
        </div>
    </div>

    <br>

    <div id="Loading" class="popup_bg"></div>

    <iframe name="hidden_frame" id="hidden_frame" src="" width="0" height="0" frameborder="0" style="position: absolute;"></iframe>

    <form method="post" name="form" id="ruleForm" action="/start_apply.htm" target="hidden_frame">
    <input type="hidden" name="current_page" value="vpncli.asp">
    <input type="hidden" name="next_page" value="">
    <input type="hidden" name="next_host" value="">
    <input type="hidden" name="sid_list" value="LANHostConfig;">
    <input type="hidden" name="group_id" value="">
    <input type="hidden" name="action_mode" value="">
    <input type="hidden" name="action_script" value="">
    <input type="hidden" name="flag" value="">

    <div class="container-fluid">
        <div class="row-fluid">
             <div class="span3">
                <!--Sidebar content-->
                  <!--=====Beginning of Main Menu=====-->
                  <div class="well sidebar-nav side_nav" style="padding: 0px;">
                      <ul id="mainMenu" class="clearfix"></ul>
                      <ul class="clearfix">
                          <li>
                              <div id="subMenu" class="accordion"></div>
                          </li>
                      </ul>
                  </div>
             </div>

             <div class="span9">
                <div class="box well grad_colour_dark_blue">
                    <div id="tabMenu"></div>
                    <h2 class="box_head round_top"><#menu6#></h2>

                    <div class="round_bottom">

                        <div>
                            <ul class="nav nav-tabs" style="margin-bottom: 10px;">
                                <li class="active">
                                    <a id="tab_vpnc_cfg" href="#cfg"><#Settings#></a>
                                </li>
                                <li>
                                    <a id="tab_vpnc_ssl" href="#ssl" style="display:none"><#OVPN_Cert#></a>
                                </li>
                            </ul>
                        </div>

                        <div id="wnd_vpnc_cfg">
                            <div class="alert alert-info" style="margin: 10px;"><#VPNC_Info#></div>
                            <table class="table">
                                <tr>
                                    <th width="50%" style="padding-bottom: 0px; border-top: 0 none;"><#VPNC_Enable#></th>
                                    <td style="padding-bottom: 0px; border-top: 0 none;">
                                        <div class="main_itoggle">
                                            <div id="vpnc_enable_on_of">
                                                <input type="checkbox" id="vpnc_enable_fake" <% nvram_match_x("", "vpnc_enable", "1", "value=1 checked"); %><% nvram_match_x("", "vpnc_enable", "0", "value=0"); %>>
                                            </div>
                                        </div>
                                            <div style="position: absolute; margin-left: -10000px;">
                                            <input type="radio" name="vpnc_enable" id="vpnc_enable_1" class="input" value="1" onclick="change_vpnc_enabled();" <% nvram_match_x("", "vpnc_enable", "1", "checked"); %>><#checkbox_Yes#>
                                            <input type="radio" name="vpnc_enable" id="vpnc_enable_0" class="input" value="0" onclick="change_vpnc_enabled();" <% nvram_match_x("", "vpnc_enable", "0", "checked"); %>><#checkbox_No#>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                            <table class="table" id="tbl_vpnc_config" style="display:none">
                                <tr>
                                    <th colspan="2" style="background-color: #E3E3E3;"><#VPNC_Base#></th>
                                </tr>
                                <tr>
                                    <th width="50%"><#VPNC_Type#></th>
                                    <td>
                                        <select name="vpnc_type" id="vpnc_type" class="input" onchange="change_vpnc_type();">
                                            <option value="0" <% nvram_match_x("", "vpnc_type", "0","selected"); %>>PPTP</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_type", "1","selected"); %>>L2TP (w/o IPSec)</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_type", "2","selected"); %>>OpenVPN</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_type", "3","selected"); %>>Wireguard</option>
                                            <option value="4" <% nvram_match_x("", "vpnc_type", "4","selected"); %>>AmneziaWG</option>
                                            <option value="5" <% nvram_match_x("", "vpnc_type", "5","selected"); %>><#VPNC_Type_Singbox#></option>
                                            <option value="6" <% nvram_match_x("", "vpnc_type", "6","selected"); %>><#VPNC_Type_Xray#></option>
                                        </select>
                                        <span id="certs_hint" style="display:none" class="label label-warning"><#OVPN_Hint#></span>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_import" style="display:none">
                                    <th width="50%" style="padding-bottom: 12px;"><#VPNC_WG_ImportConf#>:</th>
                                    <td>
                                        <input style="width: 320px" type="file" id="ov_fileInput" accept=".txt,.conf,.ovpn" name="vpnc_ov_import" onChange="ov_conf_import();" onclick="this.value=''">
                                    </td>
                                </tr>
                                <tr id="vpnc_peer_row">
                                    <th><#VPNC_Peer#></th>
                                    <td>
                                        <input type="text" name="vpnc_peer" class="input" maxlength="256" size="32" value="<% nvram_get_x("", "vpnc_peer"); %>" onKeyPress="return is_string(this,event);"/>
                                        &nbsp;<span id="col_vpnc_state" style="display:none" class="label label-success"><#Connected#></span>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_port" style="display:none">
                                    <th><#OVPN_Port#></th>
                                    <td>
                                        <input type="text" maxlength="5" size="5" name="vpnc_ov_port" class="input" value="<% nvram_get_x("", "vpnc_ov_port"); %>" onkeypress="return is_number(this,event);">
                                        &nbsp;<span style="color:#888;">[ 1194/1196 ]</span>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_wg" style="display:none">
                                    <td colspan="2" style="padding: 0px; padding: 0px; border: 0 none;">

                                        <table width="100%" style="margin-bottom: 10px;">
                                            <tr>
                                                <th width="50%" style="padding-bottom: 12px;"><#VPNC_WG_ImportConf#>:</th>
                                                <td>
                                                    <input style="width: 320px" type="file" id="wg_fileInput" accept=".txt,.conf" name="vpnc_wg_import" onChange="wg_conf_import();" onclick="this.value=''">
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#VPNC_Peer#></th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_peer_endpoint" class="input" maxlength="256" size="32" value="<% nvram_get_x("", "vpnc_wg_peer_endpoint"); %>" onKeyPress="return is_string(this,event);"/>
                                                    &nbsp;<span id="col_vpnc_wg_state" style="display:none" class="label label-success"><#Connected#></span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#OVPN_Port#></th>
                                                <td>
                                                    <input type="text" maxlength="5" size="5" name="vpnc_wg_peer_port" class="input" value="<% nvram_get_x("", "vpnc_wg_peer_port"); %>" onkeypress="return is_number(this,event);">
                                                    &nbsp;<span style="color:#888;">[ 51820 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th width="50%"><#WG_Peer_Public_key#>:</th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_peer_public" class="input" maxlength="44" size="32" value="<% nvram_get_x("", "vpnc_wg_peer_public"); %>" onKeyPress="return is_string(this,event);"/>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#VPNC_WG_KeepAlive#>:</th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_peer_keepalive" class="input" maxlength="11" size="32" value="<% nvram_get_x("", "vpnc_wg_peer_keepalive"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 or min-max ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#VPNC_WG_AllowedIPS#>:</th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_peer_allowedips" class="input" maxlength="256" size="32" value="<% nvram_get_x("", "vpnc_wg_peer_allowedips"); %>" onKeyPress="return is_string(this,event);"/>
                                                    &nbsp;<span style="color:#888;">[ 0.0.0.0/0 ]</span>
                                                </td>
                                            </tr>
                                        </table>
                                        <table width="100%" style="margin-bottom: -8px;">
                                            <tr>
                                                <th colspan="2" style="background-color: #E3E3E3;"><#t2IF#></th>
                                            </tr>
                                            <tr>
                                                <th width="50%"><#VPNC_WG_Addresses#>:</th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_if_addr" class="input" maxlength="256" size="32" value="<% nvram_get_x("", "vpnc_wg_if_addr"); %>" onKeyPress="return is_string(this,event);"/>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#WG_Private_key#>:</th>
                                                <td>
                                                    <input style="-webkit-text-security: disc;" onfocus="vpnc_wg_if_private.style='-webkit-text-security: unset;'" onblur="vpnc_wg_if_private.style='-webkit-text-security: disc;'; wg_pubkey();" type="text" name="vpnc_wg_if_private" class="input" maxlength="44" size="32" value="<% nvram_get_x("", "vpnc_wg_if_private"); %>" onKeyPress="return is_string(this,event);"/>
                                                    <input type="button" class="btn btn-mini" style="outline:0" onclick="wg_genkey();" value="<#CTL_refresh#>"/>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#WG_Public_key#>:</th>
                                                <td>
                                                    <input readonly type="text" name="vpnc_wg_if_public" class="input" maxlength="44" size="32" value="<% nvram_get_x("", "vpnc_wg_if_public"); %>" onKeyPress="return is_string(this,event);"/>
                                                    <input type="button" class="btn btn-mini" style="outline:0" onclick="document.form.vpnc_wg_if_public.select(); document.execCommand('copy');" value="<#CTL_copy#>"/>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#WG_Preshared_key#>:</th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_if_preshared" class="input" maxlength="44" size="32" value="<% nvram_get_x("", "vpnc_wg_if_preshared"); %>" onKeyPress="return is_string(this,event);"/>
                                                    <input type="button" class="btn btn-mini" style="outline:0" onclick="wg_genpsk();" value="<#CTL_refresh#>"/>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#PPPConnection_x_PPPoEMTU_itemname#></th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_mtu" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_wg_mtu"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span style="color:#888;">[ 1000..1420 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#PPPConnection_x_WANDNSServer_itemname#></th>
                                                <td>
                                                    <input type="text" name="vpnc_wg_if_dns" class="input" maxlength="256" size="32" value="<% nvram_get_x("", "vpnc_wg_if_dns"); %>" onKeyPress="return is_string(this,event);"/>
                                                </td>
                                            </tr>
                                        </table>
                                        <table id="row_vpnc_awg" width="100%" style="margin-top: 10px; margin-bottom: -8px; display: none;">
                                            <tr>
                                                <th colspan="2" style="background-color: #E3E3E3;">AmneziaWG</th>
                                            </tr>
                                            <tr>
                                                <th width="50%">Jc:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_jc" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_jc"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Jmin:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_jmin" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_jmin"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Jmax:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_jmax" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_jmax"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>S1:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_s1" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_s1"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>S2:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_s2" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_s2"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>S3:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_s3" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_s3"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>S4:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_s4" class="input" maxlength="5" size="32" value="<% nvram_get_x("", "vpnc_awg_s4"); %>" onKeyPress="return is_number(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..65535 ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>H1:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_h1" class="input" maxlength="32" size="32" value="<% nvram_get_x("", "vpnc_awg_h1"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..4294967295 or min-max ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>H2:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_h2" class="input" maxlength="32" size="32" value="<% nvram_get_x("", "vpnc_awg_h2"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..4294967295 or min-max ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>H3:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_h3" class="input" maxlength="32" size="32" value="<% nvram_get_x("", "vpnc_awg_h3"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..4294967295 or min-max ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>H4:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_h4" class="input" maxlength="32" size="32" value="<% nvram_get_x("", "vpnc_awg_h4"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ 0..4294967295 or min-max ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>I1:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_i1" class="input" maxlength="4096" size="32" value="<% nvram_get_x("", "vpnc_awg_i1"); %>"/>
                                                    &nbsp;<span class="hint-nowrap">[ &lt;tags&gt; ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>HeaderProtectionKey:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_hpk" class="input" maxlength="64" size="32" value="<% nvram_get_x("", "vpnc_awg_hpk"); %>"/>
                                                    &nbsp;<span class="hint-nowrap">[ Base64 (32 bytes) ]</span>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>ContentPaddingAddition:</th>
                                                <td>
                                                    <input type="text" name="vpnc_awg_cpa" class="input" maxlength="11" size="32" value="<% nvram_get_x("", "vpnc_awg_cpa"); %>" onKeyPress="return is_range(this,event);"/>
                                                    &nbsp;<span class="hint-nowrap">[ e.g. 10-100 or 0..65535 ]</span>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>

                                <tr id="row_vpnc_singbox" style="display:none">
                                    <td colspan="2" style="padding-left: 0px; padding-right: 0px; border-top: 0 none;">
                                        <table width="100%">
                                            <tr>
                                                <th width="50%"><#VPNC_Bin_Location#></th>
                                                <td>
                                                    <span id="sb_bin_status"></span>
                                                </td>
                                            </tr>
                                            <tr id="row_sb_bin_help" style="display:none">
                                                <td colspan="2" style="border-top: 0 none; padding-top: 2px;">
                                                    <div class="alert alert-info" style="margin-bottom: 5px;">
                                                        <strong><i class="icon-info-sign"></i> <#VPNC_USB_Hint_Title#></strong><br>
                                                        <#VPNC_USB_Hint_Desc1#><br>
                                                        <div style="margin: 6px 0 6px 12px;">
                                                            1. <#VPNC_USB_Hint_Step1#><br>
                                                            2. <#VPNC_USB_Hint_Step2#> папка <code>images/sing-box</code> &rarr; <code>/media/&lt;диск&gt;/sing-box</code><br>
                                                            3. <#VPNC_USB_Hint_Step3#>
                                                        </div>
                                                        <span class="muted"><#VPNC_USB_Hint_Console#></span><br>
                                                        <pre style="font-size: 11px; margin: 4px 0;">mkdir -p /media/*/sing-box && cd /media/*/sing-box && wget -q -O - https://github.com/SagerNet/sing-box/releases/download/v1.14.0/sing-box-1.14.0-linux-mipsle-softfloat.tar.gz | tar -zx --strip-components=1 && chmod +x sing-box</pre>
                                                    </div>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#VPNC_Proxy_Routing#></th>
                                                <td>
                                                    <select name="vpnc_sb_routing" class="input" style="width: 320px;">
                                                        <option value="0" <% nvram_match_x("", "vpnc_sb_routing", "0","selected"); %>><#VPNC_Proxy_Routing_Full#></option>
                                                        <option value="1" <% nvram_match_x("", "vpnc_sb_routing", "1","selected"); %>><#VPNC_Proxy_Routing_Unblock#></option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th colspan="2" style="padding-top: 10px; border-bottom: 0 none;">
                                                    <a href="javascript:spoiler_toggle('spoiler_sb_conf')"><span><#VPNC_SB_Config#></span> <i style="scale: 75%;" class="icon-chevron-down"></i></a>
                                                    &nbsp;&nbsp;
                                                    <button type="button" class="btn btn-mini btn-info" onclick="load_sb_template('hy2');"><#VPNC_Load_Hy2_Template#></button>
                                                    <button type="button" class="btn btn-mini" onclick="load_sb_template('vless');">VLESS Template</button>
                                                </th>
                                            </tr>
                                            <tr>
                                                <td colspan="2" id="spoiler_sb_conf" style="border-top: 0 none; padding-top: 4px;">
                                                    <textarea rows="16" wrap="off" spellcheck="false" maxlength="32768" class="span12" id="scripts.singbox_config.json" name="scripts.singbox_config.json" style="resize:vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("scripts.singbox_config.json",""); %></textarea>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>

                                <tr id="row_vpnc_xray" style="display:none">
                                    <td colspan="2" style="padding-left: 0px; padding-right: 0px; border-top: 0 none;">
                                        <table width="100%">
                                            <tr>
                                                <th width="50%"><#VPNC_Bin_Location#></th>
                                                <td>
                                                    <span id="xray_bin_status"></span>
                                                </td>
                                            </tr>
                                            <tr id="row_xray_bin_help" style="display:none">
                                                <td colspan="2" style="border-top: 0 none; padding-top: 2px;">
                                                    <div class="alert alert-info" style="margin-bottom: 5px;">
                                                        <strong><i class="icon-info-sign"></i> <#VPNC_USB_Hint_Title#></strong><br>
                                                        <#VPNC_USB_Hint_Desc1#><br>
                                                        <div style="margin: 6px 0 6px 12px;">
                                                            1. <#VPNC_USB_Hint_Step1#><br>
                                                            2. <#VPNC_USB_Hint_Step2#> папка <code>images/xray</code> &rarr; <code>/media/&lt;диск&gt;/xray</code><br>
                                                            3. <#VPNC_USB_Hint_Step3#>
                                                        </div>
                                                    </div>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th><#VPNC_Proxy_Routing#></th>
                                                <td>
                                                    <select name="vpnc_xray_routing" class="input" style="width: 320px;">
                                                        <option value="0" <% nvram_match_x("", "vpnc_xray_routing", "0","selected"); %>><#VPNC_Proxy_Routing_ProxyOnly#></option>
                                                        <option value="1" <% nvram_match_x("", "vpnc_xray_routing", "1","selected"); %>><#VPNC_Proxy_Routing_Unblock#></option>
                                                    </select>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th colspan="2" style="padding-top: 10px; border-bottom: 0 none;">
                                                    <a href="javascript:spoiler_toggle('spoiler_xray_conf')"><span><#VPNC_XRAY_Config#></span> <i style="scale: 75%;" class="icon-chevron-down"></i></a>
                                                    &nbsp;&nbsp;
                                                    <button type="button" class="btn btn-mini btn-info" onclick="load_xray_template();"><#VPNC_Load_Vless_Template#></button>
                                                </th>
                                            </tr>
                                            <tr>
                                                <td colspan="2" id="spoiler_xray_conf" style="border-top: 0 none; padding-top: 4px;">
                                                    <textarea rows="16" wrap="off" spellcheck="false" maxlength="32768" class="span12" id="scripts.xray_config.json" name="scripts.xray_config.json" style="resize:vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("scripts.xray_config.json",""); %></textarea>
                                                </td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>

                                <tr id="row_vpnc_ov_prot" style="display:none">
                                    <th><#OVPN_Prot#></th>
                                    <td>
                                        <select name="vpnc_ov_prot" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_prot", "0","selected"); %>>UDP over IPv4</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_prot", "1","selected"); %>>TCP over IPv4 (*)</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_ov_prot", "2","selected"); %>>UDP over IPv6</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_ov_prot", "3","selected"); %>>TCP over IPv6</option>
                                            <option value="4" <% nvram_match_x("", "vpnc_ov_prot", "4","selected"); %>>UDP both</option>
                                            <option value="5" <% nvram_match_x("", "vpnc_ov_prot", "5","selected"); %>>TCP both</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_mode" style="display:none">
                                    <th><#OVPN_Mode#></th>
                                    <td>
                                        <select name="vpnc_ov_mode" class="input" onchange="change_vpnc_ov_mode();">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_mode", "0","selected"); %>>L2 - TAP (Ethernet)</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_mode", "1","selected"); %>>L3 - TUN (IP) (*)</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_auth" style="display:none">
                                    <th><#OVPN_Auth#></th>
                                    <td>
                                        <select name="vpnc_ov_auth" class="input" onchange="change_vpnc_ov_auth();">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_auth", "0","selected"); %>>TLS: client.crt/client.key</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_auth", "1","selected"); %>>TLS: username/password</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_user">
                                    <th><#ISP_Authentication_user#></th>
                                    <td>
                                       <input type="text" maxlength="64" class="input" size="32" name="vpnc_user" value="<% nvram_get_x("", "vpnc_user"); %>" onkeypress="return is_string(this,event);"/>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_pass">
                                    <th><#ISP_Authentication_pass#></th>
                                    <td>
                                        <div class="input-append">
                                            <input type="password" maxlength="64" class="input" size="32" name="vpnc_pass" id="vpnc_pass" style="width: 175px;" value="<% nvram_get_x("", "vpnc_pass"); %>"/>
                                            <button style="margin-left: -5px;" class="btn" type="button" onclick="passwordShowHide('vpnc_pass')"><i class="icon-eye-close"></i></button>
                                        </div>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_auth">
                                    <th><#VPNS_Auth#></th>
                                    <td>
                                        <select name="vpnc_auth" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_auth", "0","selected"); %>>Auto</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_auth", "1","selected"); %>>MS-CHAPv2</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_auth", "2","selected"); %>>CHAP</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_auth", "3","selected"); %>>PAP</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_mppe">
                                    <th><#VPNS_Ciph#></th>
                                    <td>
                                        <select name="vpnc_mppe" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_mppe", "0","selected"); %>>Auto</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_mppe", "1","selected"); %>>MPPE-128</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_mppe", "2","selected"); %>>MPPE-40</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_mppe", "3","selected"); %>>No encryption</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_mtu">
                                    <th>MTU:</th>
                                    <td>
                                        <input type="text" maxlength="4" size="5" name="vpnc_mtu" class="input" value="<% nvram_get_x("", "vpnc_mtu"); %>" onkeypress="return is_number(this,event);"/>
                                        &nbsp;<span style="color:#888;">[1000..1460]</span>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_mru">
                                    <th>MRU:</th>
                                    <td>
                                        <input type="text" maxlength="4" size="5" name="vpnc_mru" class="input" value="<% nvram_get_x("", "vpnc_mru"); %>" onkeypress="return is_number(this,event);"/>
                                        &nbsp;<span style="color:#888;">[1000..1460]</span>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_pppd">
                                    <th style="padding-bottom: 0px;"><#PPPConnection_x_AdditionalOptions_itemname#></th>
                                    <td style="padding-bottom: 0px;">
                                        <input type="text" name="vpnc_pppd" value="<% nvram_get_x("", "vpnc_pppd"); %>" class="input" maxlength="255" size="32" onKeyPress="return is_string(this,event);" />
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_mdig" style="display:none">
                                    <th><#VPNS_Auth#></th>
                                    <td>
                                        <select name="vpnc_ov_mdig" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_mdig", "0","selected"); %>>[MD5] MD-5, 128 bit</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_mdig", "1","selected"); %>>[SHA1] SHA-1, 160 bit (*)</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_ov_mdig", "2","selected"); %>>[SHA224] SHA-224, 224 bit</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_ov_mdig", "3","selected"); %>>[SHA256] SHA-256, 256 bit</option>
                                            <option value="4" <% nvram_match_x("", "vpnc_ov_mdig", "4","selected"); %>>[SHA384] SHA-384, 384 bit</option>
                                            <option value="5" <% nvram_match_x("", "vpnc_ov_mdig", "5","selected"); %>>[SHA512] SHA-512, 512 bit</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_ciph" style="display:none">
                                    <th><#VPNS_Ciph#></th>
                                    <td>
                                        <select name="vpnc_ov_ciph" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_ciph", "0","selected"); %>>[none]</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_ciph", "1","selected"); %>>[DES-CBC] DES, 64 bit</option>
                                            <option value="2" <% nvram_match_x("", "vpnc_ov_ciph", "2","selected"); %>>[DES-EDE-CBC] 3DES, 128 bit</option>
                                            <option value="3" <% nvram_match_x("", "vpnc_ov_ciph", "3","selected"); %>>[BF-CBC] Blowfish, 128 bit</option>
                                            <option value="4" <% nvram_match_x("", "vpnc_ov_ciph", "4","selected"); %>>[AES-128-CBC] AES, 128 bit (*)</option>
                                            <option value="5" <% nvram_match_x("", "vpnc_ov_ciph", "5","selected"); %>>[AES-192-CBC] AES, 192 bit</option>
                                            <option value="6" <% nvram_match_x("", "vpnc_ov_ciph", "6","selected"); %>>[DES-EDE3-CBC] 3DES, 192 bit</option>
                                            <option value="7" <% nvram_match_x("", "vpnc_ov_ciph", "7","selected"); %>>[DESX-CBC] DES-X, 192 bit</option>
                                            <option value="8" <% nvram_match_x("", "vpnc_ov_ciph", "8","selected"); %>>[AES-256-CBC] AES, 256 bit</option>
                                            <option value="9" <% nvram_match_x("", "vpnc_ov_ciph", "9","selected"); %>>[CAMELLIA-128-CBC] CAM, 128 bit</option>
                                            <option value="10" <% nvram_match_x("", "vpnc_ov_ciph", "10","selected"); %>>[CAMELLIA-192-CBC] CAM, 192 bit</option>
                                            <option value="11" <% nvram_match_x("", "vpnc_ov_ciph", "11","selected"); %>>[CAMELLIA-256-CBC] CAM, 256 bit</option>
                                            <option value="12" <% nvram_match_x("", "vpnc_ov_ciph", "12","selected"); %>>[AES-128-GCM] AES-GCM, 128 bit</option>
                                            <option value="13" <% nvram_match_x("", "vpnc_ov_ciph", "13","selected"); %>>[AES-192-GCM] AES-GCM, 192 bit</option>
                                            <option value="14" <% nvram_match_x("", "vpnc_ov_ciph", "14","selected"); %>>[AES-256-GCM] AES-GCM, 256 bit</option>
                                            <option value="15" <% nvram_match_x("", "vpnc_ov_ciph", "15","selected"); %>>[CHACHA20-POLY1305], 256 bit</option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_ncp_clist" style="display:none">
                                    <th><#OVPN_NCP_clist#></th>
                                    <td>
                                        <input type="text" maxlength="256" size="15" name="vpnc_ov_ncp_clist" class="input" style="width: 286px;" value="<% nvram_get_x("", "vpnc_ov_ncp_clist"); %>" onkeypress="return is_string(this,event);"/>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_compress" style="display:none">
                                    <th><#OVPN_COMPRESS#></th>
                                    <td>
                                        <select name="vpnc_ov_compress" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_compress", "0","selected"); %>><#btn_Disable#> (*)</option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_compress", "1","selected"); %>><#OVPN_COMPRESS_Item1#></option>
                                            <option value="2" <% nvram_match_x("", "vpnc_ov_compress", "2","selected"); %>><#OVPN_COMPRESS_Item2#></option>
                                            <option value="3" <% nvram_match_x("", "vpnc_ov_compress", "3","selected"); %>><#OVPN_COMPRESS_Item3#></option>
                                            <option value="4" <% nvram_match_x("", "vpnc_ov_compress", "4","selected"); %>><#OVPN_COMPRESS_Item4#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_atls" style="display:none">
                                    <th><#OVPN_HMAC#></th>
                                    <td>
                                        <select name="vpnc_ov_atls" class="input" onchange="change_vpnc_ov_atls();">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_atls", "0","selected"); %>><#checkbox_No#></option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_atls", "1","selected"); %>><#OVPN_HMAC_Item1#></option>
                                            <option value="2" <% nvram_match_x("", "vpnc_ov_atls", "2","selected"); %>><#OVPN_HMAC_Item2#></option>
                                            <option value="3" <% nvram_match_x("", "vpnc_ov_atls", "3","selected"); %>><#OVPN_USE_TCV2_ItemC#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_cnat" style="display:none">
                                    <th><#OVPN_Topo#></th>
                                    <td>
                                        <select name="vpnc_ov_cnat" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_ov_cnat", "0","selected"); %>><#OVPN_Topo1#></option>
                                            <option value="1" <% nvram_match_x("", "vpnc_ov_cnat", "1","selected"); %>><#OVPN_Topo2#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_ov_conf" style="display:none">
                                    <td colspan="2" style="padding-bottom: 0px;">
                                        <div style="margin-bottom: 4px;">
                                            <a href="javascript:spoiler_toggle('spoiler_vpnc_ov_conf')"><span><#OVPN_User#></span></a>
                                            <button type="button" class="btn btn-mini btn-info pull-right" onclick="open_modal_editor('ovpncli.client.conf', '<#OVPN_User#>');"><i class="icon-resize-full icon-white"></i> Редактор в окне</button>
                                        </div>
                                        <div id="spoiler_vpnc_ov_conf" style="display:none;">
                                            <textarea rows="18" wrap="off" spellcheck="false" class="span12" name="ovpncli.client.conf" style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("ovpncli.client.conf",""); %></textarea>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                            <table class="table" id="tbl_vpnc_server">
                                <tr>
                                    <th colspan="2" style="background-color: #E3E3E3;"><#VPNC_VPNS#></th>
                                </tr>
                                <tr>
                                    <th width="50%"><#VPNC_SFW#></th>
                                    <td>
                                        <select name="vpnc_sfw" class="input" style="width: 320px;">
                                            <option value="1" <% nvram_match_x("", "vpnc_sfw", "1","selected"); %>><#VPNC_SFW_Item1#></option>
                                            <option value="3" <% nvram_match_x("", "vpnc_sfw", "3","selected"); %>><#VPNC_SFW_Item3#></option>
                                            <option value="0" <% nvram_match_x("", "vpnc_sfw", "0","selected"); %>><#VPNC_SFW_Item0#></option>
                                            <option value="2" <% nvram_match_x("", "vpnc_sfw", "2","selected"); %>><#VPNC_SFW_Item2#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="vpnc_get_dns">
                                    <th id="vpnc_use_dns"><#VPNC_PDNS#></th>
                                    <td>
                                        <select name="vpnc_pdns" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_pdns", "0","selected"); %>><#checkbox_No#></option>
                                            <option value="1" <% nvram_match_x("", "vpnc_pdns", "1","selected"); %>><#VPNC_PDNS_Item1#></option>
                                            <option value="2" <% nvram_match_x("", "vpnc_pdns", "2","selected"); %>><#VPNC_PDNS_Item2#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr>
                                    <th><#VPNC_DGW#></th>
                                    <td>
                                        <select name="vpnc_dgw" class="input">
                                            <option value="0" <% nvram_match_x("", "vpnc_dgw", "0","selected"); %>><#checkbox_No#></option>
                                            <option value="1" <% nvram_match_x("", "vpnc_dgw", "1","selected"); %>><#checkbox_Yes#></option>
                                        </select>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_remote_network" style="display: none">
                                    <td colspan="2">
                                        <div style="margin-bottom: 4px;">
                                            <a href="javascript:spoiler_toggle('spoiler_vpnc_remote_network')"><span><#VPNC_RNet_List#>:</span></a>
                                            <button type="button" class="btn btn-mini btn-info pull-right" onclick="open_modal_editor('scripts.vpnc_remote_network.list', '<#VPNC_RNet_List#>');"><i class="icon-resize-full icon-white"></i> Редактор в окне</button>
                                        </div>
                                        <div id="spoiler_vpnc_remote_network" style="display: none">
                                            <textarea rows="18" wrap="off" spellcheck="false" class="span12" name="scripts.vpnc_remote_network.list" style="font-family:'Courier New'; font-size:12px; resize:vertical;"><% nvram_dump("scripts.vpnc_remote_network.list",""); %></textarea>
                                        </div>
                                    </td>
                                </tr>
                                <tr id="row_vpnc_exclude_network" style="display: none">
                                    <td colspan="2">
                                        <div style="margin-bottom: 4px;">
                                            <a href="javascript:spoiler_toggle('spoiler_vpnc_exclude_network')"><span><#VPNC_ExcludeList#>:</span></a>
                                            <button type="button" class="btn btn-mini btn-info pull-right" onclick="open_modal_editor('scripts.vpnc_exclude_network.list', '<#VPNC_ExcludeList#>');"><i class="icon-resize-full icon-white"></i> Редактор в окне</button>
                                        </div>
                                        <div id="spoiler_vpnc_exclude_network" style="display: none">
                                            <textarea rows="18" wrap="off" spellcheck="false" class="span12" name="scripts.vpnc_exclude_network.list" style="font-family:'Courier New'; font-size:12px; resize:vertical;"><% nvram_dump("scripts.vpnc_exclude_network.list",""); %></textarea>
                                        </div>
                                    </td>
                                </tr>
                                <tr>
                                    <td colspan="2" style="padding-bottom: 0px;">
                                        <div style="margin-bottom: 4px;">
                                            <a href="javascript:spoiler_toggle('spoiler_script')"><span><#RunPostVPNC#></span></a>
                                            <button type="button" class="btn btn-mini btn-info pull-right" onclick="open_modal_editor('scripts.vpnc_server_script.sh', '<#RunPostVPNC#>');"><i class="icon-resize-full icon-white"></i> Редактор в окне</button>
                                        </div>
                                        <div id="spoiler_script" style="display:none;">
                                            <textarea rows="18" wrap="off" spellcheck="false" class="span12" name="scripts.vpnc_server_script.sh" style="font-family:'Courier New'; font-size:12px; resize:vertical;"><% nvram_dump("scripts.vpnc_server_script.sh",""); %></textarea>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                            <table class="table" id="tbl_vpnc_route" style="display:none">
                                <tr>
                                    <th colspan="2" style="background-color: #E3E3E3;"><#VPNC_Route#></th>
                                </tr>
                                <tr>
                                    <th width="50%"><#VPNC_RNet#></th>
                                    <td>
                                        <input type="text" maxlength="15" size="14" name="vpnc_rnet" style="width: 94px;" value="<% nvram_get_x("", "vpnc_rnet"); %>" onKeyPress="return is_ipaddr(this,event);" />&nbsp;/
                                        <input type="text" maxlength="15" size="14" name="vpnc_rmsk" style="width: 94px;" value="<% nvram_get_x("", "vpnc_rmsk"); %>" onKeyPress="return is_ipaddr(this,event);" />
                                    </td>
                                </tr>
                            </table>
                            <table class="table">
                                <tr>
                                    <td style="border: 0 none; padding: 0px;"><center><input name="button" type="button" class="btn btn-primary" style="width: 219px" onclick="applyRule();" value="<#CTL_apply#>"/></center></td>
                                </tr>
                            </table>
                        </div>

                        <div id="wnd_vpnc_ssl" style="display:none">
                            <table class="table">
                                <tr>
                                    <td style="padding-bottom: 0px; border-top: 0 none;">
                                        <span class="caption-bold">ca.crt (Root CA Certificate):</span>
                                        <textarea rows="4" wrap="off" spellcheck="false" class="span12" name="ovpncli.ca.crt" style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("ovpncli.ca.crt",""); %></textarea>
                                    </td>
                                </tr>
                                <tr id="row_client_crt">
                                    <td style="padding-bottom: 0px; border-top: 0 none;">
                                        <span class="caption-bold">client.crt (Client Certificate):</span>
                                        <textarea rows="4" wrap="off" spellcheck="false" class="span12" name="ovpncli.client.crt" style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("ovpncli.client.crt",""); %></textarea>
                                    </td>
                                </tr>
                                <tr id="row_client_key">
                                    <td style="padding-bottom: 0px; border-top: 0 none;">
                                        <span class="caption-bold">client.key (Client Private Key) - secret:</span>
                                        <textarea rows="4" wrap="off" spellcheck="false" class="span12" name="ovpncli.client.key" style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("ovpncli.client.key",""); %></textarea>
                                    </td>
                                </tr>
                                <tr id="row_ta_key">
                                    <td style="padding-bottom: 0px; border-top: 0 none;">
                                        <span class="caption-bold">ta.key/tc.key(ctc2.key) (TLS Auth/Crypt(Crypt-v2) Key) - secret:</span>
                                        <textarea rows="4" wrap="off" spellcheck="false" class="span12" name="ovpncli.ta.key" style="resize: vertical; font-family:'Courier New'; font-size:12px;"><% nvram_dump("ovpncli.ta.key",""); %></textarea>
                                    </td>
                                </tr>
                            </table>
                            <table class="table">
                                <tr>
                                    <td style="border: 0 none;"><center><input name="button2" type="button" class="btn btn-primary" style="width: 219px" onclick="applyRule();" value="<#CTL_apply#>"/></center></td>
                                </tr>
                            </table>
                        </div>

                    </div>
                </div>
             </div>
        </div>
    </div>
    </form>

    <div id="footer"></div>
</div>

    <!-- Modal Text Editor -->
    <div id="modal_text_editor" class="modal hide fade modal-editor" tabindex="-1" role="dialog" aria-hidden="true">
        <div class="modal-header">
            <button type="button" class="close" data-dismiss="modal" aria-hidden="true">&times;</button>
            <h4 id="modal_editor_title" style="margin: 0; display: inline-block;"><#CTL_modify#></h4>
            <span class="badge badge-info" id="modal_editor_stats" style="margin-left: 15px; font-size: 11px;">0 lines | 0.0 KB</span>
        </div>
        <div class="modal-body">
            <div style="margin-bottom: 8px;">
                <div class="btn-group">
                    <button type="button" class="btn btn-small" onclick="modal_editor_dedup();" title="Удалить повторяющиеся строки"><i class="icon-filter"></i> Удалить дубли</button>
                    <button type="button" class="btn btn-small" onclick="modal_editor_clean();" title="Удалить пустые строки и пробелы"><i class="icon-trash"></i> Удалить пустые</button>
                    <button type="button" class="btn btn-small" onclick="modal_editor_sort();" title="Сортировать строки"><i class="icon-list"></i> Сортировка</button>
                </div>
                <div class="pull-right">
                    <input type="file" id="modal_file_input" style="display:none;" onchange="modal_editor_load_file(this);" accept=".txt,.list,.conf">
                    <button type="button" class="btn btn-small btn-inverse" onclick="document.getElementById('modal_file_input').click();" title="Загрузить из файла"><i class="icon-folder-open icon-white"></i> Загрузить файл</button>
                    <button type="button" class="btn btn-small" onclick="modal_editor_copy();" title="Скопировать всё в буфер"><i class="icon-share"></i> <#CTL_copy#></button>
                </div>
            </div>
            <textarea id="modal_editor_content" wrap="off" spellcheck="false" oninput="update_modal_editor_stats();" onkeyup="update_modal_editor_stats();"></textarea>
        </div>
        <div class="modal-footer">
            <span id="modal_editor_msg" style="float: left; color: #468847; font-weight: bold; margin-top: 5px;"></span>
            <button type="button" class="btn" data-dismiss="modal" aria-hidden="true"><#CTL_Cancel#></button>
            <button type="button" class="btn btn-info" onclick="modal_editor_apply();"><i class="icon-ok icon-white"></i> <#CTL_onlysave#> в форму</button>
            <button type="button" class="btn btn-primary" onclick="modal_editor_apply_and_save();"><i class="icon-check icon-white"></i> <#CTL_apply#></button>
        </div>
    </div>

</body>
</html>
