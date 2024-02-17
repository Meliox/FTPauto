#!/bin/bash
#checking if freespace is sufficient before filetransfer, show space used
function server_sizemanagement { 
	if [[ $test_mode != "true" ]]; then
		local mode=$1
		cat "$login_file1" >> "$server_freespace_file"
		echo "du -s $incomplete > ~/../../$server_size_file" >> "$server_freespace_file"
		echo "wait" >> "$server_freespace_file"
		echo "du -s $complete > ~/../../$server_size_file" >> "$server_freespace_file"
		echo "quit" >> "$server_freespace_file"
		echo "INFO: Looking up used space, this may take a while......"
		$lftp -f "$server_freespace_file" &> /dev/null		
		if [[ $? -eq 0 ]]; then
			# server online, continue to find size
			server_getsize $mode
		else
			retry_count="0"
			if [[ $mode == "info" ]]; then
				while [[ $retry_count -lt $retries ]]; do
					echo -e "\e[00;31mERROR: Looking up free space failed for some reason!\e[00m"
					echo -e "\e[00;31mTransfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
					waittime=$(($retry_download*60))
					echo "INFO: Pausing session and trying again $retry_download"mins" later"
					sed "3s#.*#***************************	SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
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
				quittime=$(( $scriptstart + $retry_download_max*60*60 )) #hours
				echo "INFO: Keep trying until $(date --date=@$quittime)"			
				while [[ $(date +%s) -lt $quittime ]]; do
					echo -e "\e[00;31mERROR: Looking up free space failed for some reason!\e[00m"
					echo -e "\e[00;31mTransfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
					waittime=$(($retry_download*60))
					echo "INFO: Pausing session and trying again $retry_download"mins" later"
					sed "3s#.*#***************************	SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
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
			sed "3s#.*#***************************	SERVER INFO: SERVER OFFLINE#" -i $logfile
			is_online="1"
		fi
	else
		echo -e "\e[00;31mTESTMODE: LFTP-sizemanagement NOT STARTED\e[00m"
		echo "Would look up free space at server host rootdir"
	fi
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
		sed "3s#.*#***************************	SERVER INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		echo "INFO: Free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		cleanup session;
		;;
	"check" )
		sed "3s#.*#***************************	SERVER INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		if [[ "$( echo "$freemb < $critical" | bc)" -eq "1" ]] || [[ "$( echo "$size > $freemb" | bc)" -eq "1" ]]; then
			sed "3s#.*#***************************	SERVER INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED!#" -i $logfile
			freespaceneeded=$(echo $size - $freemb | bc)
			sed "5s#.*#***************************	PENDING: "$orig_name" needs "$freespaceneeded"MB additional free space#" -i $logfile
			echo "INFO: SERVER: "$usedmb"/"$totalmb"MB Used"
			echo -e "\e[00;31mERROR: SERVER: Free space: "$freemb"MB\e[00m"
			echo -e "\e[00;31mERROR: "$orig_name" needs "$freespaceneeded"MB additional free space\e[00m"
			echo "INFO: Stopping session and trying again $retry_download"mins" later"
			cleanup session
			echo -e "INFO: Exiting current session\n"
			waittime=$(($retry_download*60))
			sed "3s#.*#***************************	SERVER INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
			sleep $waittime
			queue run #running new session
		fi
		usedcrit=$(( $totalmb - $critical ))
		echo "INFO: SERVER OK - free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		;;
	esac
}