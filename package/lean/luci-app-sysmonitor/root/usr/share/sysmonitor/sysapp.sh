#!/bin/bash

NAME=sysmonitor
APP_PATH=/usr/share/$NAME
SYSLOG='/var/log/sysmonitor.log'

echolog() {
	local d="$(date "+%Y-%m-%d %H:%M:%S")"
	echo -e "$d: $*" >>$SYSLOG
	number=$(cat $SYSLOG|wc -l)
	[ $number -gt 25 ] && sed -i '1,10d' $SYSLOG
}

uci_get_by_name() {
	local ret=$(uci get $1.$2.$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_get_by_type() {
	local ret=$(uci get $1.@$2[0].$3 2>/dev/null)
	echo ${ret:=$4}
}

uci_set_by_name() {
	uci set $1.$2.$3=$4 2>/dev/null
	uci commit $1
}

uci_set_by_type() {
	uci set $1.@$2[0].$3=$4 2>/dev/null
	uci commit $1
}

agh() {
file1="/etc/AdGuardHome.yaml"
if [ -f $file1 ]; then
	status='Stopped'
	[ $(ps -w|grep -v grep|grep AdGuardHome|wc -l) -gt 0 ] && status='Running'
	num1=$(sed -n '/upstream_dns:/=' $file1)
	let num1=num1+1
	tmp='sed -n '$num1'p '$file1
	adguardhome=$($tmp)
	echo $status$adguardhome
else
	echo ""
fi
}

ssr() {
	ssrstatus=''
	ssr=''
	ssrp=''
	[ -f "/etc/init.d/shadowsocksr" ] && ssr='Shadowsocksr '
	[ -f "/etc/init.d/passwall" ] && ssrp='Passwall '
	if [ ! "$ssr" == '' ]; then
		ssrstatus='Stopped'
		[ "$(ps -w |grep /etc/ssrplus |grep -v grep |wc -l)" -gt 0 ] && ssrstatus='Running'
	fi
	if [ ! "$ssrp" == '' ]; then
		ssrpstatus='Stopped'
		[ "$(ps -w |grep /etc/passwall |grep -v grep |wc -l)" -gt 0 ] && ssrpstatus='Running'
	fi
	if [ "$ssr" == '' -a "$ssrp" == '' ]; then
		echo "No VPN Server installed."
	else
		if [ "$ssrstatus" == 'Running' ]; then
			echo $ssr$ssrstatus
		elif [ "$ssrpstatus" == 'Running' ]; then
			echo $ssrp$ssrpstatus
		else
			echo "VPN "$ssrpstatus
		fi
	fi
}

ipsec_users() {
	if [ -f "/usr/sbin/ipsec" ]; then
		users=$(/usr/sbin/ipsec status|grep xauth|grep ESTABLISHED|wc -l)
		usersl2tp=$(top -bn1|grep options.xl2tpd|grep -v grep|wc -l)
		let "users=users+usersl2tp"
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

pptp_users() {
	if [ -f "/usr/sbin/pppd" ]; then
		users=$(top -bn1|grep options.pptpd|grep -v grep|wc -l)
#		let users=users-1
		[ "$users" == 0 ] && users='None'
	else
		users='None'
	fi
	echo $users
}

wg_users() {
file='/var/log/wg_users'
/usr/bin/wg >$file
m=$(sed -n '/peer/=' $file | sort -r -n )
k=$(cat $file|wc -l)
let "k=k+1"
s=$k
for n in $m
do 
	let "k=s-n"
	if [ $k -le 3 ] ;then 
		let "s=s-1"
		tmp='sed -i '$n,$s'd '$file
		$tmp
	else
		let "i=n+3"
		tmp='sed -n '$i'p '$file
		tmp=$($tmp|cut -d' ' -f6)
		[ "$tmp" == "hour," ] && tmp="hours,"
		[ "$tmp" == "minute," ] && tmp="minutes,"	
		case $tmp in
		hours,)
			let "s=s-1"
			tmp='sed -i '$n,$s'd '$file
			$tmp
			;;
		minutes,)
			tmp='sed -n '$i'p '$file
			tmp=$($tmp|cut -d' ' -f5)
			if [ $tmp -ge 3 ] ;then
				let "s=s-1"
				tmp='sed -i '$n,$s'd '$file
				$tmp
			fi
			;;
		esac
	fi
	s=$n
done
users=$(cat $file|sed "/GWLcAE1Of.*$/d"|grep peer|wc -l)
#[ "$users" == 0 ] && users='None'
echo $users
}

wg() {
	if [ $(uci_get_by_name $NAME sysmonitor wgenable 0) == 0 ]; then
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 0 ]; then
			wg_name=$(ifconfig |grep wg[0-9] |cut -c1-3)
			for x in $wg_name; do
			    ifdown $x &
			done
		fi
	else
		if [ $(ifconfig |grep wg[0-9] |cut -c3-3|wc -l) != 3 ]; then
			wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
			wg_name="wg1 wg2 wg3"
			for x in $wg_name; do
				[ $(echo $wg|grep $x|wc -l) == 0 ] && ifup $x
			done
		fi
	fi
	wg=$(ifconfig |grep wg[0-9] |cut -c1-3)
	echo $wg
}

ad_del() {
	file1="/etc/AdGuardHome.yaml"
	num1=$(sed -n '/upstream_dns:/=' $file1)
	num2=$(sed -n '/upstream_dns_file:/=' $file1)
	let num1=num1+1
	let num2=num2-1
	tmp='sed -i '$num1','$num2'd '$file1
	[ $num1 -le $num2 ] && $tmp
}

ad_switch() {
	[ ! -f "/etc/init.d/AdGuardHome" ] && return
	adguardhome="  - "$1
	file1="/etc/AdGuardHome.yaml"
	if [ -f $file1 ]; then
		ad_del "upstream_dns:" "upstream_dns_file:"
		sed -i '/upstream_dns:/asqmshcn' $file1
		sed -i "s|sqmshcn|$adguardhome|g" $file1
		[ $(uci_get_by_name AdGuardHome AdGuardHome enabled 0) == 1 ] && /etc/init.d/AdGuardHome force_reload >/dev/null
	fi
}

switch_vpn() {
	if [ "$(ps -w|grep /etc/passwall|grep -v grep|wc -l)" == 0 ]; then
		if [ -f "/etc/init.d/passwall" ]; then
			uci set passwall.@global[0].enabled=1
			uci commit passwall
			/etc/init.d/passwall restart &
		fi
		echo "Passwall"
	elif [ "$(ps -w|grep /etc/ssrplus|grep -v grep|wc -l)" == 0 ]; then	
		[ -f "/etc/init.d/shadowsocksr" ] && /etc/init.d/shadowsocksr restart &
		echo "Shadowsocksr"
	fi
}

firmware () {
	[ ! -d "/tmp/upload" ] && mkdir /tmp/upload
	cd /tmp/upload
	firmware=$(uci get sysmonitor.sysmonitor.firmware)
	[ "$1" != '' ] && firmware=$1
	tmp=$(echo $firmware|cut -d'/' -f 9)
	 [ -f $tmp ] && rm $tmp
	echolog "Download Firmware:"$tmp"..."
	wget  --no-check-certificate -c $firmware -O $tmp
	echolog "Download Firmware is OK.Please go to Update"
}

getip() {
	ifname=$(uci get network.wan6.ifname)
	ip=$(ip -o -4 addr list $ifname | cut -d ' ' -f7 | cut -d'/' -f1)
	echo $ip >/www/ip.html
	echo $ip
}

getip6() {
	ifname=$(uci get network.wan6.ifname)
	ip=$(ip -o -6 addr list $ifname | cut -d ' ' -f7 | cut -d'/' -f1 |head -n1)
	echo $ip >/www/ip6.html
	echo $ip
}

gethost() {
	if [ -n "$1" ]; then
		vpn=$1		
	else
		vpn=$(uci get sysmonitor.sysmonitor.vpnip)
	fi
	host=$(nslookup $vpn|grep name|cut -d'=' -f2|cut -d' ' -f2)
	[ ! -n "$host" ] && host=$vpn
	echo $host
}

service_smartdns() {
	if [ "$(ps |grep smartdns|grep -v grep|wc -l)" == 0 ]; then
		uci set sysmonitor.sysmonitor.smartdns=1
	else
		uci set sysmonitor.sysmonitor.smartdns=0
	fi
	uci commit sysmonitor
	/etc/init.d/sysmonitor restart
}

service_sys() {
	if [ "$(uci get sysmonitor.sysmonitor.enable)" == 0 ]; then
		uci set sysmonitor.sysmonitor.enable=1
	else
		uci set sysmonitor.sysmonitor.enable=0
	fi
	uci commit sysmonitor
	/etc/init.d/sysmonitor restart
}

service_ddns() {
	if [ "$(ps |grep dynamic_dns|grep -v grep|wc -l)" == 0 ]; then
		uci set sysmonitor.sysmonitor.ddns=1
	else
		uci set sysmonitor.sysmonitor.ddns=0
	fi
	uci commit sysmonitor
	/etc/init.d/sysmonitor restart
}

vpns() {
	vpnlist=$(uci get sysmonitor.sysmonitor.vpn)
	if [ ! -n "$vpnlist" ]; then
		uci set sysmonitor.sysmonitor.vpn='192.168.1.110'
		uci commit sysmonitor
		vpnlist=$(uci get sysmonitor.sysmonitor.vpn)
	fi
	vpnip=$(uci get sysmonitor.sysmonitor.vpnip)
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
	[ "$k" == 0 ] && vpnip=$(echo $vpnlist|cut -d' ' -f1)
	uci set sysmonitor.sysmonitor.vpnip=$vpnip
	uci commit sysmonitor
	touch /tmp/sysmonitor
}

setdns() {
	dnslist=$(uci get sysmonitor.sysmonitor.dns)
	if [ "$dnslist" != "$(uci get network.lan.dns)" ]; then
		d=$(date "+%Y-%m-%d %H:%M:%S")
		echo $d": Set DNS "$dnslist >> /var/log/sysmonitor.log
		uci del network.wan.dns
		uci del network.lan.dns
		for n in $dnslist
		do 		
			uci add_list network.wan.dns=$n
			uci add_list network.lan.dns=$n
		done
		uci commit network
		ifup lan
		ifup wan
		ifup wan6
		/etc/init.d/odhcpd restart
	fi
}

refresh() {
arg=$(ps | grep sysmonitor.sh | grep -v grep | wc -l)
if [ $arg == 0 ]; then
	/etc/init.d/sysmonitor restart
elif [ $arg == 1 ]; then
	touch /tmp/sysmonitor
else
	killall sysmonitor.sh
	/etc/init.d/sysmonitor restart
fi
}

arg1=$1
shift
case $arg1 in
refresh)
	refresh
	;;
setdns)
	setdns
	;;
vpns)
	vpns
	;;
service_smartdns)
	service_smartdns
	;;
service_ddns)
	service_ddns
	;;
service_sys)
	service_sys
	;;
getip)
	getip
	;;
getip6)
	getip6
	;;
gethost)
	gethost $1
	;;
agh)
	agh
	;;
ssr)
	ssr
	;;
ipsec)
	ipsec_users
	;;
pptp)
	pptp_users
	;;
wg)
	wg_users
	;;
switch_vpn)
	switch_vpn
	;;
ad_switch)
	ad_switch $1
	;;
firmware)
	firmware $1
	;;
esac
