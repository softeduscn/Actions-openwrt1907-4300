#!/bin/bash

[ "$(ps | grep sysmonitor.sh | grep -v grep | wc -l)" -gt 2 ] && exit

sleep_unit=1
NAME=sysmonitor
APP_PATH=/usr/share/$NAME

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

ping_url() {
	local url=$1
	for i in $( seq 1 3 ); do
		status=$(ping -c 1 -W 1 $url | grep -o 'time=[0-9]*.*' | awk -F '=' '{print$2}'|cut -d ' ' -f 1)
		[ "$status" == "" ] && status=0
		[ "$status" != 0 ] && break
	done
	echo $status
}

curl_url() {
	url=$1"/.getvpn.php"
	for i in $( seq 1 2 ); do
		result=$(curl -s --connect-timeout 1 $url)
		[ -n "$result" ] && break
	done
	echo $result
}

check_ip() {
	if [ ! -n "$1" ]; then
		#echo "NO IP!"
		echo ""
	else
 		IP=$1
    		VALID_CHECK=$(echo $IP|awk -F. '$1<=255&&$2<=255&&$3<=255&&$4<=255{print "yes"}')
		if echo $IP|grep -E "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$">/dev/null; then
			if [ ${VALID_CHECK:-no} == "yes" ]; then
				# echo "IP $IP available."
				echo $IP
			else
				#echo "IP $IP not available!"
				echo ""
			fi
		else
			#echo "IP is name convert ip!"
			dnsip=$(nslookup $IP|grep Address|sed -n '2,2p'|cut -d' ' -f2)
			if [ ! -n "$dnsip" ]; then
				#echo "Inull"
				echo $test
			else
				#echo "again check"
				echo $(check_ip $dnsip)
			fi
		fi
	fi
}

setdns() {
	d=$(date "+%Y-%m-%d %H:%M:%S")
	echo $d": gateway="$homeip >> /var/log/sysmonitor.log
	uci set network.wan.gateway=$homeip
	uci set network.wan.dns="$(uci get network.lan.dns)"
	uci commit network
	ifup wan
	ifup wan6
	/etc/init.d/odhcpd restart
}

selvpn() {
	vpnlist=$(uci get sysmonitor.sysmonitor.vpn)
	if [ ! -n "$vpnlist" ]; then
		uci set sysmonitor.sysmonitor.vpn='192.168.1.110'
		uci commit sysmonitor
		vpnlist=$(uci get sysmonitor.sysmonitor.vpn)
	fi
	vpnip=$1
	k=0
	for n in $vpnlist
	do
		if [ "$k" == 1 ]; then
			vpnip=$n
			break
		fi
		[ "$vpnip" == "$n" ] && {
			k=1
			vpnip=$(echo $vpnlist|cut -d' ' -f1)
		}
	done
	echo $vpnip
}

[ ! $(uci get dhcp.lan.ra) == "relay" ] && touch /tmp/relay
[ ! $(uci get dhcp.lan.ndp) == "relay" ] && touch /tmp/relay
[ ! $(uci get dhcp.lan.dhcpv6) == "relay" ] && touch /tmp/relay
[ -f /tmp/relay ] && {
	uci set dhcp.lan.ra='relay'
	uci set dhcp.lan.dhcpv6='relay'
	uci set dhcp.lan.ndp='relay'
	uci commit dhcp
	/etc/init.d/odhcpd restart &
}

sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null

gateway=$(uci get network.wan.gateway)
d=$(date "+%Y-%m-%d %H:%M:%S")
echo $d": Sysmonitor is up." >> /var/log/sysmonitor.log
echo $d": gateway="$gateway >> /var/log/sysmonitor.log
while [ "1" == "1" ]; do #死循环
	ifname=$(uci get network.wan6.ifname)
	ipv6=$(ip -o -6 addr list $ifname|cut -d ' ' -f7)
	cat /www/ip6.html | grep $(echo $ipv6|cut -d'/' -f1 |head -n1) > /dev/null
	[  $? -ne 0 ] && {
		d=$(date "+%Y-%m-%d %H:%M:%S")
		echo $d": IP6:"$ipv6 >> /var/log/sysmonitor.log
		echo $ipv6|cut -d'/' -f1|head -n1 >/www/ip6.html
	}
	homeip=$(uci_get_by_name $NAME sysmonitor homeip 0)
	vpnip=$(uci_get_by_name $NAME sysmonitor vpnip 0)
	gateway=$(uci get network.wan.gateway)
#	status=$(ping_url $vpnip)
#	if [ "$status" == 0 ]; then
	status=$(curl_url $vpnip)
	if [ ! -n "$status" ]; then
		vpnip=$(selvpn $(uci get sysmonitor.sysmonitor.vpnip))
		status=$(curl_url $vpnip)
		if [ ! -n "$status" ];then
			[ "$(uci get network.wan.gateway)" != "$homeip" ] && setdns
		else
			uci set sysmonitor.sysmonitor.vpnip=$vpnip
			uci commit sysmonitor
		fi
	fi
	if [ ! -n "$status" ]; then
		[ "$gateway" == "$vpnip" ] && setdns
	else
		if [ ! "$gateway" == "$vpnip" ]; then
			d=$(date "+%Y-%m-%d %H:%M:%S")
			echo $d": VPN-gateway="$vpnip >> /var/log/sysmonitor.log
			uci set network.wan.gateway=$vpnip
#			uci del network.wan.dns
#			uci add_list network.wan.dns=$vpnip
			uci commit network
			ifup wan
			ifup wan6
			/etc/init.d/odhcpd restart
		fi
	fi
	num=0
	check_time=$(uci_get_by_name $NAME sysmonitor time 10)
	[ "$check_time" -le 3 ] && check_time=3
	while [ $num -le $check_time ]; do
		sleep $sleep_unit
		if [ $(uci_get_by_name $NAME sysmonitor enable 0) == 0 ]; then
			setdns
			d=$(date "+%Y-%m-%d %H:%M:%S")
			echo $d": Sysmonitor is down." >> /var/log/sysmonitor.log
			killall sysmonitor.sh &
			exit 0
		fi
		let num=num+sleep_unit
		if [ -f "/tmp/sysmonitor" ]; then
			rm /tmp/sysmonitor
			num=50
		fi
	done
done


