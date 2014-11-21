#!/bin/sh

# Network traffic monitor
# Purpose is to shut down server or do anything else if network traffic is below threshold due to
# low activity

# Do you want to monitor your netcard or the firewall? The netcard cannot see more traffic than
# allow by the bit of your system, i.e. 2^32 = 4gb. So 32bit is limited. A wrap has been used to
# fix this, but total traffic cannot be seen. Find the correct interface/network to use using ifconfig.
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
echo "Monitoring network card in order to shutdown when there's no traffic."
echo "Threshold=$threshold MB per interval $monitor_time mins. Times below threshold in order to shut down $times times"
echo "Monitoring $interface"
low_times=0
while :; do
	if [ "$rxbytes" ] ; then
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
		if [ $rxbytes -lt $oldtxbytes ] || [ $txbytes -lt $oldtxbytes ]; then
			low_times=0
			echo "Too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
			sleep $(( $monitor_time * 60 ))
			continue
		fi
		# low activty counter
		if [ $rxunit == "Mb" -o $rxunit == "Kb" -o $rxunit == "b" ] && [ $txunit == "Mb" -o $txunit == "Kb" -o $txunit == "b" ]; then
			if [ $rxbytes_diff -gt "$threshold" -a $rxunit == "Mb" ] || [ $txbytes_diff -gt "$threshold" -a $txunit == "Mb" ]; then
				# Too much traffic
				low_times=0
				echo "Too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
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
			echo "Too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
			sleep $(( $monitor_time * 60 ))
			continue
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
