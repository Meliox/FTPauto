#!/bin/sh
version="0.7"
# Network traffic monitor
# Purpose is to shut down server or do anything else if network traffic is below threshold due to
# low activity

# Do you want to monitor your netcard or the firewall? The netcard cannot see more traffic than
# allow by the bit of your system, i.e. 2^32 = 4gb. (32bit limit, 64bit goes to 2.3exabytes). A wrap has been used to
# fix this while using netcard, but total traffic cannot be seen for fast speeds. At low speeds the purpose of the
# script works. For correct transfer, the 64bit system is required or the use of iptables.
#
# Proper traffic count can be seen with iptables, but
# this requires to set op iptables rules like below
# Add monitor for INPUT and OUTPUT. REQUIRED!
# iptables -A INPUT -j ACCEPT
# iptables -A OUTPUT -j ACCEPT
#
# This assumes information is in third line like below. Edit line if this ins't the case
# Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
# pkts      bytes target     prot opt in     out     source               destination
# 1941988 1207873331 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED
# 627   183690 ACCEPT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0
# 0        0 ACCEPT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0
# 0        0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0
#
# See your output by iptables -nx -vL <OUTPUT|INPUT>
#

# Another option is to monitor if certain ips are online, enter those in hosts. This setting overwrites
# the minimum traffic treshold! This is meant as an addon.

# USAGE
# Following argument can be used: start, stop.
# start for starting networkmonitor
# stop for stopping a running networkmonitor
#
# Settings below
#
threshold=10 		# MB per interval
monitor_time=5 		# mins per inverval
times=3 		# number of times it should be below threshold in each interval
lockfile="networkmonitor.lock"
log="networkmonitor.log"
shutdown_command="poweroff"	#command to execute for shutdown

method="netcard" 	# iptables or netcard
interface="eth0" 	# only for netcard.
line="3"		# only for iptables
add_iptables="no"	# add iptables -A INPUT -j ACCEPT and iptables -A OUTPUT -j ACCEPT to
			# iptables upon script start

hosts=""		# iphosts, seperate with :. Leave empty if not used. Format 192.168.1.1

enable="0" 		# 1 the shutdown command is evaluated, 0 for testing purposes

################# CODE BELOW ################3

control_c() {
	# run if user hits control-c
	rm "$lockfile"
	exit 0
}
trap control_c SIGINT

printrxbytes(){
	if [ $method == "netcard" ]; then
		ifconfig "$interface" | grep "RX bytes" | cut -d: -f2 | awk '{ print $1 }'
	elif [ $method == "iptables" ]; then
		iptables -nx -vL INPUT | cut -d' ' -f3 |  awk ' NR == 3'
	fi
}

printtxbytes(){
	if [ $method == "netcard" ]; then
		ifconfig "$interface" | grep "TX bytes" | cut -d: -f3 | awk '{ print $1 }'
	elif [ $method == "iptables" ]; then
		iptables -nx -vL OUTPUT | cut -d' ' -f3 |  awk ' NR == 3'
	fi
}

bytestohuman(){
multiplier="0"
number="$1"
while [ "$number" -ge 1024 ] ; do
	multiplier=$(($multiplier+1))
	number=$(($number/1024))
done
echo "$number"
}

bytestohumanunit(){
multiplier="0"
number="$1"
while [ "$number" -ge 1024 ] ; do
	multiplier=$(($multiplier+1))
	number=$(($number/1024))
done
case "$multiplier" in
	1)
	unit="Kb"
	;;
	2)
	unit="Mb"
	;;
	3)
	unit="Gb"
	;;
	4)
	unit="Tb"
	;;
	*)
	unit="b"
	;;
esac
echo "$unit"
}

printresults(){
counter=30000
while [ "$counter" -ge 0 ] ; do
	counter=$(($counter - 1))
	if [ "$rxbytes" ] ; then
		oldrxbytes="$rxbytes"
		oldtxbytes="$txbytes"
	fi
	rxbytes=$(printrxbytes)
	txbytes=$(printtxbytes)
	if [ "$oldrxbytes" -a "$rxbytes" -a "$oldtxbytes" -a "$txbytes" ] ; then
		echo "RXbytes = $(bytestohuman $(($rxbytes - $oldrxbytes))) $(bytestohumanunit $(($rxbytes - $oldrxbytes)))	TXbytes = $(bytestohuman $(($txbytes - $oldtxbytes))) $(bytestohumanunit $(($txbytes - $oldtxbytes)))"
	else
		echo "Monitoring $interface every $sleep seconds. (RXbyte total = $(bytestohuman $rxbytes) $(bytestohumanunit $(($rxbytes - $oldrxbytes))) TXbytes total = $(bytestohuman $txbytes)) $(bytestohumanunit $(($txbytes - $oldtxbytes)))"
	fi
	#sleep "$monitor_time"
	sleep 20
done
}

bytestomegabyts(){
	number=$(($1/1024))
	echo $number
}

shutdowntimer(){
# Write startup message
echo "Networking monitor $version"
echo ""
echo "Monitoring networkcard=$interface for traffic."
if [[ -n $hosts ]]; then
	echo "Monitoring for online hosts: $hosts"
fi
echo "Settings: Threshold=$threshold MB. Interval $monitor_time mins. Treshold $times times."
echo
low_times=0
while :; do
	# first check if any online ip's
	checkip
	# only if the one ip is online reset counter and skip traffic calculation
	if  [[ $iponline == "yes" ]]; then
		echo "Online hosts found: $ipfound"
		low_times=0
	else
		if [ "$rxbytes" ]; then
			oldrxbytes="$rxbytes"
			oldtxbytes="$txbytes"
		fi
		rxbytes=$(printrxbytes)
		txbytes=$(printtxbytes)
		if [ "$oldrxbytes" -a "$rxbytes" -a "$oldtxbytes" -a "$txbytes" ] ; then
			rxunit=$(bytestohumanunit $(($rxbytes - $oldrxbytes)))
			rxbytes_diff=$(bytestohuman $(($rxbytes - $oldrxbytes)))
			txunit=$(bytestohumanunit $(($txbytes - $oldtxbytes)))
			txbytes_diff=$(bytestohuman $(($txbytes - $oldtxbytes)))

			# wrap around 2^32 count limit on 32bit systems. Reseting counter if lower!
			if [ $rxbytes -lt $oldrxbytes ] || [ $txbytes -lt $oldtxbytes ]; then
				low_times=0
				if [ $rxbytes_diff -gt 0 ] && [ $txbytes_diff -gt 0 ]; then
					echo "too high traffic.. RXbytes = adaptor reset N/A TXbytes = adaptor reset N/A"
				elif [ $rxbytes_diff -gt 0 ] && [ $txbytes_diff -lt 0 ]; then
					 echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = adaptor reset N/A"
				elif [ $rxbytes_diff -lt 0 ] && [ $txbytes_diff -gt 0 ]; then
					 echo "too high traffic.. RXbytes = adaptor reset N/A TXbytes = $txbytes_diff $txunit"
				fi
				sleep $(( $monitor_time * 60 ))
				continue
			fi
			# low activty counter
			if [ $rxunit == "Mb" -o $rxunit == "Kb" -o $rxunit == "b" ] && [ $txunit == "Mb" -o $txunit == "Kb" -o $txunit == "b" ]; then
				if [ $rxbytes_diff -gt "$threshold" -a $rxunit == "Mb" ] || [ $txbytes_diff -gt "$threshold" -a $txunit == "Mb" ]; then
					# Too much traffic
					low_times=0
					echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
					sleep $(( $monitor_time * 60 ))
					continue
				fi
				let low_times++
				echo "too low traffic, $low_times times.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
				if [ $low_times -eq $times  ]; then
					echo "time for shutdown"
					rm "$lockfile"
					echo "$(date): No network activity, shutting down.!" >> "$log"
					if [ $enable -eq 1 ]; then
						eval "$shutdown_command"
					fi
					exit 0
				fi
			else
				low_times=0
				echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
				sleep $(( $monitor_time * 60 ))
				continue
			fi
		fi
	fi
	sleep $(( $monitor_time * 60 ))
done
}

lockfile(){
if [[ -f "$lockfile" ]]; then
	mypid_script=$(sed -n 1p "$lockfile")
	kill -0 $mypid_script
	if [[ $? -eq 1 ]]; then
		echo "Network monitor is not running"
		rm "$lockfile"
		echo $$ > "$lockfile"
	else
		echo "Network monitor is already running. Exiting..."
		exit 1
	fi
else
	echo $$ > "$lockfile"
fi
if [[ $add_iptables == "yes" ]] && [[ $method == "iptables" ]]; then
	iptables_add
fi
}

checkip(){
ipfound=""
iponline="no" # assume none is online
old_ifs=$IFS
IFS=:
for ip in $hosts ; do
	IFS=$old_ifs
	ping "$ip" -w 2 &> /dev/null
	if [[ $? -eq 0 ]]; then
		iponline="yes"
		ipfound="$ip"
		break
	else
		iponline="no"
	fi
done
IFS=$Old_ifs
}

# New to add the iptables
iptables_add(){
	# check if rules exists
	local var=$(iptables --list-rules | grep "\-A INPUT -j ACCEPT")
	if [[ -z "$var" ]]; then
		iptables -A INPUT -j ACCEPT
	fi
	unset var
	local var=$(iptables --list-rules | grep "\-A OUTPUT -j ACCEPT")
	if [[ -z "$var" ]]; then
		iptables -A OUTPUT -j ACCEPT
	fi
	unset var
}

case $1 in
	start)
	lockfile
	shutdowntimer
	#printresults
	;;
	stop)
	if [ -f "$lockfile" ]; then
		mypid_script=$(sed -n 1p "$lockfile")
	        kill -9 $mypid_script
		rm "$lockfile"
	else
		echo "Not running"
	fi
	exit 0
	;;
esac
