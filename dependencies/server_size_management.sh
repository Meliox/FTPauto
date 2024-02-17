#!/bin/bash
function ftp_sizemanagement { #checking if freespace is sufficient before filetransfer, show ftpspace used
	if [[ $test_mode != "true" ]]; then
		local mode=$1
		cat "$ftplogin_file1" >> "$ftpfreespace_file"
		echo "du -s $ftpincomplete > ~/../../$ftp_size_file" >> "$ftpfreespace_file"
		echo "wait" >> "$ftpfreespace_file"
		echo "du -s $ftpcomplete > ~/../../$ftp_size_file" >> "$ftpfreespace_file"
		echo "quit" >> "$ftpfreespace_file"
		echo "INFO: Looking up used space, this may take a while......"
		$lftp -f "$ftpfreespace_file" &> /dev/null		
		if [[ $? -eq 0 ]]; then
			# server online, continue to find size
			ftp_getsize $mode
		else
			retry_count="0"
			if [[ $mode == "info" ]]; then
				while [[ $retry_count -lt $retries ]]; do
					echo -e "\e[00;31mERROR: Looking up free space failed for some reason!\e[00m"
					echo -e "\e[00;31mTransfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
					waittime=$(($retry_download*60))
					echo "INFO: Pausing session and trying again $retry_download"mins" later"
					sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
					sleep $waittime
					let retry_count++
					$lftp -f "$ftpfreespace_file" &> /dev/null
					if [[ $? -eq 0 ]]; then
						# server online, continue to find size
						ftp_getsize $mode
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
					sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
					sleep $waittime
					let retry_count++
					$lftp -f "$ftpfreespace_file" &> /dev/null
					if [[ $? -eq 0 ]]; then
						# server online, continue to find size
						ftp_getsize $mode
						is_online="0"
						break					
					fi
				done			
			fi
		fi
		if [[ $is_online -ne 0 ]]; then
			# ok we failed
			sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE#" -i $logfile
			is_online="1"
		fi
	else
		echo -e "\e[00;31mTESTMODE: LFTP-sizemanagement NOT STARTED\e[00m"
		echo "Would look up free space at FTP host rootdir"
	fi
}

function ftp_getsize {
	usedkb=$(cat "$ftp_size_file" | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}')
	rm $ftpfreespace_file
	if [[ $usedkb -ge "1" ]]; then
		usedmb=$(( $usedkb / 1024 ))
	else
		usedmb="0"
	fi
	freemb=$(( $totalmb - $usedmb ))
	case "$1" in
	"info" )
		sed "3s#.*#***************************	FTP INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		echo "INFO: Free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		cleanup session;
		;;
	"check" )
		sed "3s#.*#***************************	FTP INFO: "$usedmb"\/"$totalmb"MB (Free "$freemb"MB)#" -i $logfile
		if [[ "$( echo "$freemb < $critical" | bc)" -eq "1" ]] || [[ "$( echo "$size > $freemb" | bc)" -eq "1" ]]; then
			sed "3s#.*#***************************	FTP INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED!#" -i $logfile
			freespaceneeded=$(echo $size - $freemb | bc)
			sed "5s#.*#***************************	PENDING: "$orig_name" needs "$freespaceneeded"MB additional free space#" -i $logfile
			echo "INFO: FTPSERVER: "$usedmb"/"$totalmb"MB Used"
			echo -e "\e[00;31mERROR: FTPSERVER: Free space: "$freemb"MB\e[00m"
			echo -e "\e[00;31mERROR: "$orig_name" needs "$freespaceneeded"MB additional free space\e[00m"
			echo "INFO: Stopping session and trying again $retry_download"mins" later"
			cleanup session
			echo -e "INFO: Exiting current session\n"
			waittime=$(($retry_download*60))
			sed "3s#.*#***************************	FTP INFO: "$usedmb"\/"$totalmb"MB - FREE SPACE IS CRITICAL! DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
			sleep $waittime
			queue run #running new session
		fi
		usedcrit=$(( $totalmb - $critical ))
		echo "INFO: FTP OK - free space: "$freemb"MB ("$usedmb"/"$totalmb"MB used)"
		;;
	esac
}