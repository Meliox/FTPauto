#!/bin/bash
function online_test { #confirm that server is alive and writable
	online
	if [[ $? -eq 0 ]]; then
		writeable # Check if server is writable
	else # not online
		if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi;
		echo -e "\e[00;31m [RETRYING]\e[00m"
		retry_count="0"
		# before download
		if [[ $confirm_online == "true" ]]; then
			# continue trying acording to setttings
			quittime=$(( $scriptstart + $retry_download_max*60*60 )) #hours
			echo "INFO: Keep trying until $(date --date=@$quittime)"
			if [[ $(date +%s) -lt $quittime ]]; then
				echo -e "INFO: Stopping session and trying again $retry_download"mins" later\n"
				cleanup session
				waittime=$(($retry_download*60))
				sed "3s#.*#***************************  FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i "$logfile"
				sleep 10
				queue run #running new session
			fi
		fi
		# online test
		while [[ $retry_count -lt $retries ]]; do
			echo -e "\e[00;31m [RETRYING]\e[00m"
			let retry_count++			
			online
			if [[ $? -eq 0 ]]; then
				writeable
				is_online="0"
				break
			fi
		done
		# ok we failed
		if [[ $is_online -ne 0 ]]; then
			sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE#" -i $logfile
			is_online="1"
		fi
	fi
}

function writeable_test {
	if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi;
	echo -e "\e[00;32m [OK]\e[00m"
	# Confirm that path is writeable etc.
	echo -n "INFO: Checking if set path is writeable..."
	echo "Testing ftp settings for ftpautodownload" > "$ftpcheck_testfile"
	cat "$ftplogin_file1" >> "$ftpcheck_file"
	echo "put -O \"$ftpincomplete\" \"$ftpcheck_file\"" >> "$ftpcheck_file"
	echo "rm \"$ftpincomplete$(basename $ftpcheck_file)\"" >> "$ftpcheck_file"
	echo "quit" >> "$ftpcheck_file"
	$lftp -f "$ftpcheck_file" &> /dev/null
}

function online {
		echo -n "INFO: Checking if server is alive..."
		#returns 1 if ftp server is offline, takes up to 1 min!
		cat "$ftplogin_file1" >> $ftpalive_file
		echo "ls" >> $ftpalive_file
		echo "quit" >> $ftpalive_file
		$lftp -f "$ftpalive_file" &> /dev/null
}

function writeable {
		writeable_test
		if [[ -f "$ftpcheck_file" ]]; then rm "$ftpcheck_file"; fi;
		if [[ $? -eq 0 ]]; then
			echo -e "\e[00;32m [OK]\e[00m"
			is_online="0"
		else
			echo -e "\e[00;32m [RETRYING]\e[00m"
			retry_count="0"
			# before download
			if [[ $confirm_online == "true" ]]; then
				# continue trying acording to settings
				quittime=$(( $scriptstart + $retry_download_max*60*60 )) #hours
				echo "INFO: Keep trying until $(date --date=@$quittime)"
				if [[ $(date +%s) -lt $quittime ]]; then
					echo -e "INFO: Stopping session and trying again $retry_download"mins" later\n"
					cleanup session
					waittime=$(($retry_download*60))
					sed "3s#.*#***************************  FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i "$logfile"
					sleep 10
					let retry_count++
					queue run #running new session
				fi
			fi
			# online test
			while [[ $retry_count -lt $retries ]]; do
				echo -e "\e[00;31m [RETRYING]\e[00m"
				let retry_count++			
				writeable_test
			done
			# ok we failed
			sed "3s#.*#***************************	FTP INFO: SERVER NOT WRITEABLE#" -i $logfile
			is_online="1"
		fi
}