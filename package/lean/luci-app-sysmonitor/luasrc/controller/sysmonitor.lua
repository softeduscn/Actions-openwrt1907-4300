-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
   	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "settings"),_("SYSMonitor"), 20).dependent = false
	entry({"admin", "sys", "sysmonitor","settings"}, cbi("sysmonitor/setup"), _("General Settings"), 30).dependent = false
	entry({"admin", "sys", "sysmonitor", "update"}, form("sysmonitor/filetransfer"),_("Update"), 40).leaf = false
	entry({"admin", "sys", "sysmonitor", "wgusers"},form("sysmonitor/wgusers"),_("WGusers"), 50).leaf = false
	entry({"admin", "sys", "sysmonitor", "log"},form("sysmonitor/log"),_("Log"), 60).leaf = false

	entry({"admin", "sys", "sysmonitor", "wanip_status"}, call("action_wanip_status"))
	entry({"admin", "sys", "sysmonitor", "lanip_status"}, call("action_lanip_status"))
	entry({"admin", "sys", "sysmonitor", "wg_status"}, call("action_wg_status"))
	entry({"admin", "sys", "sysmonitor", "wireguard_status"}, call("action_wireguard_status"))
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status"))
	
	entry({"admin", "sys", "sysmonitor", "refresh"}, call("refresh"))
	entry({"admin", "sys", "sysmonitor", "refreshwg"}, call("refreshwg"))
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log"))
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log"))
	entry({"admin", "sys", "sysmonitor", "firmware"}, call("firmware"))
	entry({"admin", "sys", "sysmonitor", "wg_users"}, call("wg_users"))
	entry({"admin", "sys", "sysmonitor", "vpns"}, call("vpns"))
	entry({"admin", "sys", "sysmonitor", "service_smartdns"}, call("service_smartdns"))
	entry({"admin", "sys", "sysmonitor", "service_ddns"}, call("service_ddns"))
	entry({"admin", "sys", "sysmonitor", "service_sys"}, call("service_sys"))
	entry({"admin", "sys", "sysmonitor", "service_button"}, call("service_button"))
	entry({"admin", "sys", "sysmonitor", "service_lighttpd"}, call("service_lighttpd"))
end

function get_log()
	luci.http.write(luci.sys.exec("[ -f '/var/log/sysmonitor.log' ] && cat /var/log/sysmonitor.log"))
end

function clear_log()
	luci.sys.exec("echo '' > /var/log/sysmonitor.log")
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor","log"))
end

function wg_users()
	luci.http.write(luci.sys.exec("[ -f '/var/log/wg_users' ] && cat /var/log/wg_users"))
end

function get_users()
    luci.http.write(luci.sys.exec(
                        "[ -f '/var/log/ipsec_users' ] && cat /var/log/ipsec_users"))
end

function service_button()
	buttonsys='<button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_sys">Sysmonitor</a></button>'
	button=' <button class="button1"><a href="/cgi-bin/luci/admin/services/ttyd" target="_blank">Terminal</a></button>'
	buttonl=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
		buttonl=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_lighttpd">Lighttpd</a></button>'
	end
	buttond=''
	if nixio.fs.access("/etc/init.d/ddns") then
		buttond=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_ddns">DDNS</a></button>'
	end
	buttons=''
	if nixio.fs.access("/etc/init.d/smartdns") then
		buttons=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/service_smartdns">SmartDNS</a></button>'
	end
	buttonv=' <button class="button1"><a href="/cgi-bin/luci/admin/sys/sysmonitor/vpns">VPNsource</a></button>'
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_button = buttonsys..button..buttonl..buttond..buttons..buttonv
	})
end

function action_wanip_status()
	ip = luci.sys.exec("cat /www/ip.html")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wanip_state = ip..'<font color=9699cc> ip6:['..luci.sys.exec("cat /www/ip6.html")..']</font><br>gateway:'..luci.sys.exec("uci get network.wan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.wan.dns")..'</font>'
	})
end

function action_lanip_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		lanip_state = luci.sys.exec("uci get network.lan.ipaddr")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.lan.dns")..'</font>'
	})
end

function action_gateway_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		gateway_state = luci.sys.exec("uci get network.wan.gateway")
	})
end

function action_wireguard_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wireguard_state = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh wg")
	})
end

function action_wg_status()
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		wg_state = luci.sys.exec("curl -s --connect-timeout 3 http://47.100.183.141/getwg.php")
	})
end

function action_service_status()
	gateway = luci.sys.exec("uci get network.wan.gateway")
	vpn = luci.sys.exec("uci get sysmonitor.sysmonitor.vpnip")
	if ( gateway == vpn ) then
		color = "green"
	else
		color = "red"
	end
	host = string.gsub(luci.sys.exec("/usr/share/sysmonitor/sysapp.sh gethost"), '%s+', '')
	vpn = host.."-"..string.gsub(luci.sys.exec("curl -s http://"..string.gsub(vpn, '%s+', '').."/.getvpn.php"), '%s+', '').."<a href='http://"..host.."' target='_blank'>--></a>"
	vpn = "<font color="..color..">"..vpn.."</font>"
	ddns=''
	if nixio.fs.access("/etc/init.d/ddns") then
		tmp = tonumber(luci.sys.exec("ps |grep dynamic_dns|grep -v grep|wc -l"))
		if ( tmp == 0 ) then
			color="red"
		else
			color="green"
		end
		ddns = '<font color='..color..'>DDNS<a href="/cgi-bin/luci/admin/services/ddns" target="_blank">--></a></font>'
	end
	smartdns=''
	if nixio.fs.access("/etc/init.d/smartdns") then
		tmp = tonumber(luci.sys.exec("ps |grep smartdns|grep -v grep|wc -l"))
		if ( tmp == 0 ) then
			color="red"
		else
			color="green"
		end
		smartdns = ' <font color='..color..'>SmartDNS<a href="/cgi-bin/luci/admin/services/smartdns" target="_blank">--></a></font>'
	end
	lighttpd=''
	if nixio.fs.access("/etc/init.d/lighttpd") then
		tmp = tonumber(luci.sys.exec("ps |grep lighttpd|grep -v grep|wc -l"))
		if ( tmp == 0 ) then
			color="red"
		else
			color="green"
		end
		lighttpd = ' <font color='..color..'>Lighttpd</font>'
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_state = vpn..ddns..smartdns..lighttpd
	})
end

function refresh()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh refresh")	
end

function refreshwg()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("curl http://47.100.183.141/flashwg.php")	
end

function firmware()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor", "log"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh firmware")
end

function vpns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh vpns")	
end

function service_smartdns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_smartdns")	
end

function service_ddns()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_ddns")	
end

function service_sys()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/usr/share/sysmonitor/sysapp.sh service_sys")
end

function service_lighttpd()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("/etc/init.d/lighttpd start")	
end