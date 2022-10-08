-- Copyright (C) 2017
-- Licensed to the public under the GNU General Public License v3.

module("luci.controller.sysmonitor", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/sysmonitor") then
		return
	end
	entry({"admin", "sys"}, firstchild(), "SYS", 10).dependent = false
   	entry({"admin", "sys","sysmonitor"}, alias("admin", "sys","sysmonitor", "settings"),_("SYSMonitor"), 20).dependent = true
	entry({"admin", "sys", "sysmonitor","settings"}, cbi("sysmonitor/setup"), _("General Settings"), 30).dependent = true
	entry({"admin", "sys", "sysmonitor", "update"}, form("sysmonitor/filetransfer"),_("Update"), 40).leaf = true
	entry({"admin", "sys", "sysmonitor", "wgusers"},cbi("sysmonitor/wgusers"),_("WGusers"), 50).leaf = true
	entry({"admin", "sys", "sysmonitor", "log"},cbi("sysmonitor/log"),_("Log"), 60).leaf = true

	entry({"admin", "sys", "sysmonitor", "ip_status"}, call("action_ip_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_status"}, call("action_wg_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wireguard_status"}, call("action_wireguard_status")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_status"}, call("action_service_status")).leaf = true
	
	entry({"admin", "sys", "sysmonitor", "refresh"}, call("refresh")).leaf = true
	entry({"admin", "sys", "sysmonitor", "refreshwg"}, call("refreshwg")).leaf = true
	entry({"admin", "sys", "sysmonitor", "get_log"}, call("get_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "sys", "sysmonitor", "firmware"}, call("firmware")).leaf = true
	entry({"admin", "sys", "sysmonitor", "wg_users"}, call("wg_users")).leaf = true
	entry({"admin", "sys", "sysmonitor", "vpns"}, call("vpns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_smartdns"}, call("service_smartdns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_ddns"}, call("service_ddns")).leaf = true
	entry({"admin", "sys", "sysmonitor", "service_button"}, call("service_button")).leaf = true

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
	button='<button class="button1"><a href="/cgi-bin/luci/admin/services/ttyd" target="_blank">Terminal</a></button>'
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
		service_button = button..buttond..buttons..buttonv
	})
end

function action_ip_status()
	ip = luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip")
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		ip_state = ip..'<font color=9699cc> ['..luci.sys.exec("/usr/share/sysmonitor/sysapp.sh getip6")..']</font> gateway:'..luci.sys.exec("uci get network.wan.gateway")..' <font color=9699cc>dns:'..luci.sys.exec("uci get network.wan.dns")..'</font>'
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
		wg_state = luci.sys.exec("curl http://47.100.183.141/getwg.php")
	})
end

function action_service_status()
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
	luci.http.prepare_content("application/json")
	luci.http.write_json({
		service_state = ddns .. smartdns
	})
end

function refresh()
	luci.http.redirect(luci.dispatcher.build_url("admin", "sys", "sysmonitor"))
	luci.sys.exec("touch /tmp/sysmonitor")	
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
