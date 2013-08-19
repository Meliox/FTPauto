#!/bin/bash
function ftp_test { #confirm that server is alive and writable
	if [[ $online == "true" ]] || [[ $confirm_online == "true" ]]; then
		echo "INFO: Checking if server is alive..."
		#returns 1 if ftp server is offline, takes up to 1 min!
		cat $ftplogin_file >> $ftpalive_file
		echo "ls" >> $ftpalive_file
		echo "quit" >> $ftpalive_file
		$lftp -f "$ftpalive_file" #&> /dev/null
		if [[ $? -eq 0 ]]; then	
			if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi;
			echo -e "\e[00;32mSUCCESS: Server is responding!\e[00m"
			# Confirm that path is writeable etc.
				echo "INFO: Checking if set path is writeable..."
				echo "Testing ftp settings for ftpautodownload" > $ftpcheck_testfile
				cat $ftplogin_file >> $ftpcheck_file
				echo "put -O \"$ftpincomplete\" \"$ftpcheck_file\"" >> $ftpcheck_file
				echo "rm \"$ftpincomplete$(basename $ftpcheck_file)\"" >> $ftpcheck_file
				echo "quit" >> $ftpcheck_file
				$lftp -f "$ftpcheck_file" &> /dev/null
				if [[ -f "$ftpcheck_file" ]]; then rm "$ftpcheck_file"; fi;
				if [[ $? -eq 0 ]]; then
					echo -e "\e[00;32mSUCCESS: Path is writeable!\e[00m"
				else
					echo -e "\e[00;31mERROR: Path is not writeable!\e[00m"
					if [[ $confirm_online == "true" ]]; then
						echo "INFO: Stopping session and trying again $retry_download"mins" later"
						cleanup session
						echo
						waittime=$(($retry_download*60))
						sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
						sleep $waittime
						queue run #running new session
					fi				
				fi
		else
			if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi;
			echo -e "\e[00;31mERROR: Server is not responding!\e[00m"
			if [[ $confirm_online == "true" ]]; then
				echo "INFO: Stopping session and trying again $retry_download"mins" later"
				cleanup session
				echo
				waittime=$(($retry_download*60))
				sed "3s#.*#***************************	FTP INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i $logfile
				sleep $waittime
				queue run #running new session
			fi		
		fi
	fi
}