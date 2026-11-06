#!/bin/bash
#checking if freespace is sufficient before filetransfer, show space used
function server_sizemanagement {
	loadDependency DServerLogin && load_login 1
	if [[ $test_mode != "true" ]]; then
		local mode=$1
		is_online="1"
		cat "$login_file1" >> "$server_freespace_file"
		echo "du -s $incomplete >> ~/../..$server_size_file" >> "$server_freespace_file"
		echo "wait" >> "$server_freespace_file"
		echo "du -s $complete >> ~/../..$server_size_file" >> "$server_freespace_file"
		echo "quit" >> "$server_freespace_file"
		msg plain "INFO: Looking up used space, this may take a while......"
		$lftp -f "$server_freespace_file" &> /dev/null
		if [[ $? -eq 0 ]]; then
			# server online, continue to find size
			is_online="0"
			server_getsize $mode
		else
			retry_count="0"
			if [[ $mode == "info" ]]; then
				while [[ $retry_count -lt $retries ]]; do
					msg error "ERROR: Looking up free space failed for some reason!"
					msg error "Transfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')"
					waittime=$retry_download
					msg plain "INFO: Pausing session and trying again $retry_download seconds later"
					sed "3s#.*#*************************** SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime" seconds#" -i $logfile
					sleep $waittime
					let retry_count++
					$lftp -f "$server_freespace_file" &> /dev/null
					if [[ $? -eq 0 ]]; then
						# server online, continue to find size
						server_getsize $mode
						is_online="0"
						break
					fi
				done
			elif [[ $mode == "check" ]]; then
				quittime=$(( ScriptStartTime + retry_download_max*60 )) # Minutes
				msg plain "INFO: Keep trying until $(date --date=@$quittime)"
				while [[ $(date +%s) -lt $quittime ]]; do
					msg error "ERROR: Looking up free space failed for some reason!"
					msg error "Transfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')"
					waittime=$retry_download
					msg plain "INFO: Pausing session and trying again $retry_download seconds later"
					sed "3s#.*#*************************** SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime" seconds#" -i $logfile
					sleep $waittime
					let retry_count++
					$lftp -f "$server_freespace_file" &> /dev/null
					if [[ $? -eq 0 ]]; then
						# server online, continue to find size
						server_getsize $mode
						is_online="0"
						break
					fi
				done
			fi
		fi
		if [[ $is_online -ne 0 ]]; then
			# ok we failed
			sed "3s#.*#*************************** SERVER INFO: SERVER OFFLINE#" -i $logfile
			is_online="1"
		fi
	else
		msg error "TESTMODE: LFTP-sizemanagement NOT STARTED"
		msg plain "Would look up free space at server host rootdir"
	fi
	cleanup session
}

function server_getsize {
	usedkb=$(cat "$server_size_file" | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}')
	rm $server_freespace_file
	if [[ $usedkb -ge "1" ]]; then
		usedmb=$(( $usedkb / 1024 ))
	else
		usedmb="0"
	fi
	freemb=$(( $totalmb - $usedmb ))
	case "$1" in
	"info" )
		sed "3s#.*#*************************** SERVER INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		msg plain "INFO: Free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		;;
	"check" )
		sed "3s#.*#*************************** SERVER INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		if [[ "$( echo "$freemb < $critical" | bc)" -eq "1" ]] || [[ "$( echo "$size > $freemb" | bc)" -eq "1" ]]; then
			sed "3s#.*#*************************** SERVER INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED!#" -i $logfile
			freespaceneeded=$(echo $size - $freemb | bc)
			sed "5s#.*#***************************	PENDING: "$orig_name" needs "$freespaceneeded"MB additional free space#" -i $logfile
			msg plain "INFO: SERVER: "$usedmb"/"$totalmb"MB Used"
			msg error "ERROR: SERVER: Free space: "$freemb"MB"
			msg error "ERROR: "$orig_name" needs "$freespaceneeded"MB additional free space"
			msg plain "INFO: Stopping session and trying again $retry_download seconds later"
			msg plain "INFO: Exiting current session\n"
			waittime=$retry_download
			sed "3s#.*#*************************** SERVER INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED! Trying again in "$waittime" seconds#" -i $logfile
			cleanup session
			sleep $waittime
			queue next #running new session
		fi
		usedcrit=$(( $totalmb - $critical ))
		msg plain "INFO: SERVER OK - free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		;;
	esac
}