#!/bin/bash
function delay {
	# if --delay is set, wait until it ends. If start/end time is set in config use them. Delay overrules everything
	local current_epoch target_epoch sleep_seconds timediff
	if [[ -n $delay ]]; then
		current_epoch=$(date +%s)
		target_epoch=$(date -d "$delay" +%s)
		if [[ $target_epoch -gt $current_epoch ]]; then
			sleep_seconds=$(( target_epoch - current_epoch ))
			if [[ $test_mode != "true" ]]; then
				echo "INFO: Transfere has been postponed until $delay"
				timediff=$(printf '%2d:%2d:%2d' "$((sleep_seconds/(60*60)))" "$(((sleep_seconds/60)%60))" "$((sleep_seconds%60))")
				countdown "$timediff"
			else
				echo -e "\e[00;31mTESTMODE: Would delay until $delay\e[00m"
			fi
		else
			echo -e "\e[00;31mERROR: Time is older than current time, now $(date '+%m/%d/%y %H:%M') vs. delay $delay . Format should be mm/dd/yy hh:mm.\e[00m\n"
			cleanup session
			cleanup end
			exit 1
		fi
	elif [[ -n $transfer_start ]] && [[ -n $transfer_end ]] && [[ $force == "false" ]]; then
		tranfere_timeframe
	fi
}

function countdown {
	# calculate and show countdown in display
	local OLD_IFS arr seconds start end cur left IFS
	OLD_IFS="${IFS}"
	IFS=":"
	arr=( $1 )
	seconds=$((  (arr[0] * 60 * 60) + (arr[1] * 60) + arr[2]  ))
	start=$(date +%s)
	end=$((start + seconds))
	cur=$start
	while [[ $cur -lt $end ]]; do
		cur=$(date +%s)
		left=$((end-cur))
		printf "\r%02d:%02d:%02d" \
				$((left/3600)) $(((left/60)%60)) $((left%60))
		sleep 1
	done
	IFS="${OLD_IFS}"
	echo "        "
}

function queue {
	# queuesystem. If something already is running for the user, add it to queue.
	local option i old_id
	option=$2
	case "$1" in
		"add" )
		if [[ $queue_running == true ]]; then
			# task has been started from queue, no need to add it
			true
		else
			# figure out ID
			id_old=$id
			if [[ -e "$queue_file" ]]; then
				#get last id
				id=$(( $(tail -1 "$queue_file" | cut -d'|' -f1) + 1 ))
			else
				#assume this is the first one
				id="1"
			fi
			get_size "$filepath" &> /dev/null
			if [[ -e "$queue_file" ]] && [[ -n $(cat "$queue_file" | grep "$filepath") ]] && [[ -z $option ]]; then
				# passing an item which is already in queue, do nothing
				echo -e "INFO: Item already in queue. Doing nothing...\n"
				exit 0
			elif [[ "$option" == failed ]]; then
				# passing a failed item, remove it, and add it with the status failed
				failed="true"
				# remove ID from queue
				sed "/^"$id_old"/d" -i "$queue_file"
				echo "$id|$source|$filepath|$sortto|${size}MB|true|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
				echo -e "\e[00;33mINFO: Failing item: $(basename "$filepath")\e[00m"
			elif [[ "$option" == end ]]; then
				# passed item should only be queued, then exit
				source="${source}Q"
				echo "$id|$source|$filepath|$sortto|${size}MB|false|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
				echo -e "INFO: Queueing: $(basename "$filepath"), id=$id\n"
				exit 0
			else
				# passed item should be queued, e.g. when something already is being transferred
				echo "INFO: Queueid: $id"
				echo "$id|$source|$filepath|$sortto|${size}MB|false|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
			fi
		fi
		;;
		"remove" )
		#remove item according to id
		sed "/^"$id"/d" -i "$queue_file"
		# if queue is true then continue to run else stop
		if [[ $continue_queue == true ]]; then
			queue next
		else
			cleanup end
		fi
		;;
		"next" )
		# Process next item in queue from top
		if [[ -f "$queue_file" ]] && [[ -n $(cat "$queue_file") ]]; then
			i="1"
			failed="true"
			# look for non failed items
			while [[ $failed == true ]]; do
				# load next item from top
				id=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $1}' "$queue_file")
				# check if ID has failed
				failed=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $6}' "$queue_file")
				let i++
			done
			if [[ $failed == false ]]; then
				# found a non failed item, which will be downloaded
				i=$(grep -nE "^${id}|" "$queue_file" | grep -Eo '^[^:]+')
				source=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $2}' "$queue_file")
				filepath=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $3}' "$queue_file")
				sort=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $4}' "$queue_file")
				# execute main script again
				queue_running="true"
				if [[ -f "$lockfile" ]]; then
					# ensure that lockfile isn't created running queue
					lockfileRunning="true"
				fi
				echo "---------------------- Running queue ----------------------"
				echo "Transfering id=$id, $(basename "$filepath")"
				start_main --path="$filepath" --user="$username" --sortto="$sort"
			else
				# all items in the queue are marked as failed, e.g. nothing to transfer
				echo "---------------------- Failed queue -----------------------"
				while read line; do
					id=$(echo $line | cut -d'|' -f1)
					source=$(echo $line | cut -d'|' -f2)
					path=$(echo $line | cut -d'|' -f3)
					sort=$(echo $line | cut -d'|' -f4)
					size=$(echo $line | cut -d'|' -f5)
					time=$(echo $line | cut -d'|' -f7)
					echo "ID|PATH|SORT TO|SIZE(MB)|TIME"
					echo "$id|$source|$path|$sort|$size|$time"
				done < "$queue_file"
				echo -e "\nINFO: Queue does not contain non failed items. Program will end\n"
				cleanup end
				exit 1
			fi
		else
			# no queuefile found, e.g. nothing to transfer
			echo "----------------------- Empty queue -----------------------"
			if [[ -f "$queue_file" ]]; then rm "$queue_file"; fi
			echo -e "INFO: Queue is empty. Program will end\n"
			cleanup end
			exit 0
		fi
		;;
	esac
}

function ftp_transfer_process {
	# used to start and stop the lftp transfer and progressbar
	local pid_f_process
	case "$1" in
		"start" ) #start progressbar and transfer
			TransferStartTime=$(date +%s)
			ftp_processbar &
			pid_f_process=$!
			sed "3c $pid_f_process" -i "$lockfile"
			echo -e "\e[00;37mINFO: \e[00;32mTransfer started: $(date --date=@$TransferStartTime '+%d/%m/%y-%a-%H:%M:%S')\n\e[00m"
			$lftp -f "$ftptransfere_file" &> /dev/null &
			pid_transfer=$!
			sed "2c $pid_transfer" -i "$lockfile"
			wait $pid_transfer 2>/dev/null
			pid_transfer_status=$?
			TransferEndTime=$(date +%s)
		;;
		"stop-process-bar" )
			kill $(sed -n '3p' $lockfile) &> /dev/null
			wait $(sed -n '3p' "$lockfile") 2>/dev/null
			kill $(sed -n '4p' $lockfile) &> /dev/null
			wait $(sed -n '4p' "$lockfile") 2>/dev/null

		;;
	esac
}

function ftp_transfere {
	local lftp_exclude quittime waittime
	#prepare new transfer
	{
	# Write regexp to config for directory transferes
	if [[ "${#exclude_array[@]}" -gt 0 ]] && [[-n "${exclude_array[@]}" ]] && ( [[ $transfer_type = directory ]] || [[ -d "$transfer_path" ]] ); then
		for ((i=0;i<${#exclude_array[@]};i++)); do
			if [[ $i -gt 0 ]]; then
				lftp_exclude="$lftp_exclude|"
			fi
			lftp_exclude="$lftp_exclude^.*${exclude_array[i]}*"
		done
		lftp_exclude="$lftp_exclude$"
		echo "set mirror:exclude-regex \"$lftp_exclude\"" >> "$ftptransfere_file"
		echo "set mirror:no-empty-dirs true" >> "$ftptransfere_file"
	fi
	if [[ $transferetype == "downftp" ]]; then
	# handle lftp transfere for downftp
	{
		cat "$ftplogin_file1" >> "$ftptransfere_file"
		# create final directories if they don't exists
		echo "!mkdir -p \"${ftpcomplete}\"" >> "$ftptransfere_file"
		if [[ -n $ftpincomplete ]]; then
			echo "!mkdir -p \"${ftpincomplete}\"" >> "$ftptransfere_file"
		fi
		# fail if transfers fails
		echo "set cmd:fail-exit true" >> "$ftptransfere_file"
		# from get_size we know if its a file or a path!
		if [[ $transfer_type = file ]]; then
			if [[ -n $ftpincomplete ]]; then
				echo "queue get -c -O \"${ftpincomplete}\" \"${transfer_path}\"" >> "$ftptransfere_file"
			elif [[ -z $ftpincomplete ]]; then
				echo "queue get -c -O \"${ftpcomplete}\" \"${transfer_path}\"" >> "$ftptransfere_file"
			fi
		elif [[ $transfer_type = directory ]]; then
			if [[ -n $ftpincomplete ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c \"${transfer_path}\" \"${ftpincomplete}\"" >> "$ftptransfere_file"
			elif [[ -z $ftpincomplete ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c \"${transfer_path}\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			fi
		fi
		# wait for transferes to finish
		echo "wait" >> "$ftptransfere_file"
		# moving part, locally
		if [[ -n $ftpincomplete ]]; then
			if [[ $transfer_type = file ]]; then
				echo "queue !mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			elif [[ $transfer_type = directory ]]; then
				echo "queue !mv \"${ftpincomplete}${orig_name}/\" \"${ftpcomplete}/\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
		fi
		echo "wait" >> "$ftptransfere_file"
	}
	elif [[ $transferetype == "upftp" ]]; then
	# handle lftp transfere for upftp
	{
		cat "$ftplogin_file1" >> "$ftptransfere_file"
		echo "mkdir -p \"${ftpcomplete}\"" >> "$ftptransfere_file"
		# handle files for transfer
		if [[ -n "${ftpincomplete}" ]]; then
			echo "mkdir -p \"${ftpincomplete}\"" >> "$ftptransfere_file"
		fi
		# fail if transfers fails
		echo "set cmd:fail-exit true" >> "$ftptransfere_file"
		if [[ -f "$transfer_path" ]]; then
			# single file
			if [[ -n "$ftpincomplete" ]]; then
				echo "queue put -c -O \"$ftpincomplete\" \"${transfer_path}\" " >> "$ftptransfere_file"
			elif [[ -z "$ftpincomplete" ]]; then
				echo "queue put -c -O \"$ftpcomplete\" \"${transfer_path}\" " >> "$ftptransfere_file"
			fi
		elif [[ -d "$transfer_path" ]]; then
			# directory
			if [[ -n "$ftpincomplete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpincomplete}\"" >> "$ftptransfere_file" #needs fixing
			elif [[ -z "$ftpincomplete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpcomplete}\"" >> "$ftptransfere_file" #needs fixing
			fi
		fi
		# wait for transferes to finish
		echo "wait" >> "$ftptransfere_file"
		# moving part, remotely, if ftpincomplete directory is used
		if [[ -n "$ftpincomplete" ]]; then
			# correction for file and path
			if [[ -f "$filepath" ]]; then
				echo "queue mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			elif [[ -d "$filepath" ]]; then
				echo "queue mv \"${ftpincomplete}${orig_name}/\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
		fi
	}
	elif [[ $transferetype == "fxp" ]]; then
		# handle lftp transfere for fxp
		ftp_login 2
		cat "$ftplogin_file2" >> "$ftptransfere_file"
		# first login and create final directories if they don't exists on ftphost2
		echo "mkdir -p \"$ftpcomplete\"" >> "$ftptransfere_file"
		if [[ -n $ftpincomplete ]]; then
			echo "mkdir -p \"$ftpincomplete\"" >> "$ftptransfere_file"
		fi
		# fail if transfers fails
		echo "set cmd:fail-exit true" >> "$ftptransfere_file"
		# from get_size we know if its a file or a path!
		if [[ $transfer_type = file ]]; then
			# single file
			if [[ -n "$ftpincomplete" ]]; then
				echo "queue get -c ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"$transfer_path\" -o ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"$ftpincomplete\"" >> "$ftptransfere_file"
			elif [[ -z "$ftpincomplete" ]]; then
				echo "queue get -c ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"$transfer_path\" -o ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"$ftpcomplete\"" >> "$ftptransfere_file"
			fi
		elif [[ $transfer_type = directory ]]; then
			# directory
			if [[ -n "$ftpincomplete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c -RL ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"${transfer_path}\" ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"${ftpincomplete}\"" >> "$ftptransfere_file" #needs fixing
			elif [[ -z "$ftpincomplete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c -RL ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"${transfer_path}\" ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"${ftpincomplete}\"" >> "$ftptransfere_file" #needs fixing
			fi
		fi
		# wait for transferes to finish
		echo "wait" >> "$ftptransfere_file"
		# moving part, remotely, if ftpincomplete directory is used
		if [[ -n "$ftpincomplete" ]]; then
			# correction for file and path
			if [[ $transfer_type = file ]]; then
				echo "queue mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			elif [[ $transfer_type = directory ]]; then
				echo "queue mv \"${ftpincomplete}${orig_name}/\" \"${ftpcomplete}\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
		fi
	else
		echo -e "\e[00;31mERROR: FTP setting not recognized\e[00m\n"
		cleanup die
	fi
	echo "quit" >> "$ftptransfere_file"
	}
	 #start transferring
	{
	if [[ $test_mode != "true" ]]; then
		ftp_transfer_process start
		#did lftp end properly
		while [[ $pid_transfer_status -ne 0 ]]; do
			quittime=$(( ScriptStartTime + retry_download_max*60 )) #minutes
			if [[ $(date +%s) -gt $quittime ]]; then
				echo -e "\e[00;31mERROR: FTP transfer failed after max ($retry_download_max minutes)!\e[00m"
				# remove processbar processes
				ftp_transfer_process "stop-process-bar"
				# mark transfer as failed
				queue add failed
				break
			else
				echo -e "\e[00;31mERROR: FTP transfer failed for some reason!\e[00m"
				echo "INFO: Retrying until $(date --date=@$quittime '+%d/%m/%y-%a-%H:%M:%S')"
				# Kill processbar
				ftp_transfer_process "stop-process-bar"
				echo "INFO: Pausing session and trying again in 60s"
				sed "3s#.*#***************************	FTP INFO: DOWNLOAD POSTPONED! Trying again in ${retry_download}mins#" -i "$logfile"
				sleep 60
				# restart transfer
				ftp_transfer_process start
			fi
		done
		#remove processbar processes
		ftp_transfer_process "stop-process-bar"
		echo -e "\n\e[00;37mINFO: \e[00;32mTransfer ended: $(date --date=@$TransferEndTime '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
	else
		echo -e "\e[00;31mTESTMODE: LFTP-transfer NOT STARTED\e[00m"
		echo "Would execute the following in lftp:"
		cat "$ftptransfere_file" | (while read; do echo "      $REPLY"; done)
	fi
	}
}

function ftp_processbar { #Showing how download is proceeding
	local transfered_size ProgressTimeNew TransferredNew TransferredNewMB TotalTimeDiff TimeDiff percentage speed eta etatime SpeedOld sum SpeedAverage cols percentagebarlength string string2 TransferredOld ProgressTimeOld
	if [[ $test_mode != "true" ]]; then
		sleep 5 #wait for transfer to start
		if [[ $transferetype == "downftp" ]]; then
			transfered_size="du -s \"$ftpincomplete$changed_name\" > \"$proccess_bar_file\""
			if [[ $transfer_type = file ]]; then
				echo "du -s \"$ftpincomplete${orig_name}\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			elif [[ $transfer_type = directory ]]; then
				echo "du -s \"$ftpincomplete$orig_name\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			fi
		elif [[ $transferetype == "upftp" ]]; then
			#Create configfile for lftp processbar
			cat "$ftplogin_file1" >> "$ftptransfere_processbar"
			# ~ is /home/USER/
			if [[ -f "$filepath" ]]; then
				echo "du -s \"$ftpincomplete${orig_name}\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			elif [[ -d "$filepath" ]]; then
				echo "du -s \"$ftpincomplete$orig_name\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			fi
			echo "quit" >> "$ftptransfere_processbar"
		elif [[ $transferetype == "fxp" ]]; then
			#Create configfile for lftp processbar
			cat "$ftplogin_file2" >> "$ftptransfere_processbar"
			# ~ is /home/USER/
			if [[ $transfer_type = file ]]; then
				echo "du -s \"$ftpincomplete${orig_name}\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			elif [[ $transfer_type = directory ]]; then
				echo "du -s \"$ftpincomplete$orig_name\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
			fi
			echo "quit" >> "$ftptransfere_processbar"
		fi
		{ #run processbar loop
		while :; do
			if [[ $transferetype == "downftp" ]]; then
				eval $transfered_size
			elif [[ $transferetype == "upftp" ]] || [[ $transferetype == "fxp" ]]; then
				$lftp -f "$ftptransfere_processbar" &> /dev/null &
				pid_process=$!
				sed "4c $pid_process" -i "$lockfile"
				wait $pid_process
			fi
			# get first time and size. First time, set time, restart loop
			if [[ ! -a "$proccess_bar_file" ]]; then
				# no transferred information
				continue
			elif [[ -z "$TransferredOld" ]] && [[ -a "$proccess_bar_file" ]]; then
				# transferred information available
				TransferredOld=$(cat $proccess_bar_file | awk '{print $1}')
				ProgressTimeOld=$(date +%s)
				rm "$proccess_bar_file"
				continue
			fi
			# Feedback received
			if [[ -a "$proccess_bar_file" ]]; then
				# set current time
				ProgressTimeNew=$(date +%s)
				# Get new transferred information
				TransferredNew=$(cat "$proccess_bar_file" | awk '{print $1}')
				TransferredNewMB=$(echo $TransferredNew / 1024 | bc)
				TotalTimeDiff=$(( ProgressTimeNew - TransferStartTime ))
				# calculate data
				TimeDiff=$(printf '%02dh:%02dm:%02ds' "$((TotalTimeDiff/(60*60)))" "$(((TotalTimeDiff/60)%60))" "$((TotalTimeDiff%60))")
				# Ensure value are valid
				if [[ "$(( $TransferredNew - $TransferredOld ))" -ge "1" ]] && [[ "$(( $TransferredNew - $TransferredOld ))" =~ ^[0-9]+$ ]]; then
					percentage=$(echo "scale=4; ( $TransferredNew / ( $directorysize / ( 1024 ) ) ) * 100" | bc)
					percentage=$(echo $percentage | sed 's/\(.*\)../\1/')
					speed=$(echo "scale=2; ( ($TransferredNew - $TransferredOld) / 1024 ) / ( $ProgressTimeNew - $ProgressTimeOld )" | bc) # MB/s
					eta=$(echo "( ($directorysize / 1024 ) - $TransferredNew ) / ($speed * 1024 )" | bc)
					etatime=$(printf '%02dh:%02dm:%02ds' "$(($eta/(60*60)))" "$((($eta/60)%60))" "$(($eta%60))")
					# Calculate average speed. Needs to be calculated each time as transfer stops ftp_processbar
					SpeedOld+=( "$speed" )
					if [[ -n "${#SpeedOld[@]}" ]]; then
						sum="0"
						for i in "${SpeedOld[@]}"; do
							sum=$(echo "( $sum + $i )" | bc)
						done
						SpeedAverage=$(echo "scale=2; $sum / ${#SpeedOld[@]}" | bc)
						sed "5c $SpeedAverage" -i "$lockfile"
						# we can start overwriting progresline
						tput cuu 1;	tput el1
					fi
					else
						speed="?"
						SpeedAverage="?"
						percentage="0"
						etatime="?"
				fi
				#update file and output the current line
				sed "5s#.*#***************************	Transferring: ${orig_name}, $percentage%%, in $TimeDiff, $speed MB/s(current), ETA: $etatime, ${SpeedAverage} MB/s (avg)   #" -i "$logfile"
				cols=$(($(tput cols) - 2))
				percentagebarlength=$(echo "scale=0; $percentage * $cols / 100" | bc)
				string="$(eval printf "=%.0s" '{1..'"$percentagebarlength"\})"
				string2="$(eval printf "\ %.0s" '{1..'"$(($cols - $percentagebarlength - 1))"\})"
				if [[ $percentagebarlength -eq 0 ]]; then
					printf "\r[$string2]      (no transfere information yet) ($(date '+%H:%M:%S'))"
				elif [[ $(echo "scale=0; $cols - $percentagebarlength - 1" | bc) -eq 0 ]]; then
					printf "\r[$string>]      $percentage%% ETA ${etatime}@${speed}MB/s. ${TransferredNewMB}MB@${SpeedAverage}MB/s(avg). ($(date '+%H:%M:%S'))"
				else
					printf "\r[$string>$string2]      $percentage%% ETA ${etatime}@${speed}MB/s. ${TransferredNewMB}MB@${SpeedAverage}MB/s(avg). ($(date '+%H:%M:%S'))"
				fi
			fi
			# update variables and wait
			TransferredOld="$TransferredNew"
			ProgressTimeOld="$ProgressTimeNew"
			rm "$proccess_bar_file"
			sleep $sleeptime
		done
		}
		#new line
		echo -ne '\n'
	else
		echo -e "\e[00;31mTESTMODE: LFTP-processbar NOT STARTED\e[00m"
	fi
}

function logrotate {
	if [[ $test_mode != "true" ]]; then
			transferTime=$(( $TransferEndTime - $TransferStartTime ))
			transferTime2=$(printf '%02dh:%02dm:%02ds' "$(($transferTime/(60*60)))" "$((($transferTime/60)%60))" "$(($transferTime%60))")
			SpeedAverage=$(sed -n 5p "$lockfile")
			#Adds new info to 7th line
			sed "7i $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')|${source}|${orig_name}|${size}MB|${transferTime2}|${SpeedAverage}MB/s" -i "$logfile"
			lognumber=$((7 + $lognumber ))
			#Add text to old file
			if [[ $logrotate == "true" ]]; then
				if [[ -n $(sed -n $lognumber,'$p' "$logfile") ]]; then
					sed -n $lognumber,'$p' "$logfile" >> "$oldlogfile"
				fi
			fi
			#Remove text from old file
			if [ "$lognumber" -ne 0 ]; then
				sed $lognumber,'$d' -i "$logfile"
			fi
			totaldl=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f4)
			totaldl=${totaldl%MB}
			if [[ -z "$totaldl" ]]; then
				totaldl="0"
			fi
			totaldl=$(echo "$totaldl + $size" | bc)
			totalrls=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f6)
			totalrls=$(echo "$totalrls + 1" | bc)
			totaldltime=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f10)
			totaldltime_seconds=$(awk 'BEGIN{split("'$totaldltime'",a,":"); print a[1]*(60*60*24)+a[2]*(60*60)+a[3]*60+a[4];}')
			totaldltime=$(echo "$totaldltime_seconds + $transferTime" | bc)
			totaldltime=$(printf '%02dd:%02dh:%02dm:%02ds' "$(($totaldltime/(60*60*24)))" "$(($totaldltime/(60*60)%24))" "$((($totaldltime/60)%60))" "$(($totaldltime%60))")

			sed "1s#.*#*****  FTPauto ${s_version}#" -i "$logfile"
			sed "2s#.*#*****  STATS: ${totaldl}MB in ${totalrls} transfers in ${totaldltime}#" -i "$logfile"
			sed "3s#.*#*****  FTP INFO: N/A#" -i "$logfile"
			sed "4s#.*#*****  LASTDL: $(date)|${orig_name}|${SpeedAverage}MB/s#" -i "$logfile"
			sed "5s#.*#*****  #" -i "$logfile"
		else
			echo -e "\e[00;31mTESTMODE: LOGGING NOT STARTED\e[00m"
	fi
}

function loadConfig {
	# reload config
	loadDependency DConfig

	#load paths to everything
	setup
}

function lockfile {
	# upon start (from queue or --path) no option is available, hence create lockfile
	if [[ -f "$lockfile" ]] && [[ $force != "true" ]]; then
		# The file exists, find PID, transfere, confirm it still is running
		mypid_script=$(sed -n 1p "$lockfile")
		mypid=$(sed -n 2p "$lockfile")
		alreadyinprogres=$(sed -n 3p "$lockfile")
		kill -0 $mypid_script &> /dev/null
		if [[ $? -eq 1 ]]; then
			#Process is not running, continue
			echo "INFO: Old lockfile found, but process is not running"
			rm -f "$lockfile"
		else
			echo "INFO: Already running"
			echo "      The script pid: $mypid_script"
			echo "      The transfere pid: $alreadyinprogres"
			echo "      Transfer: $(sed -n 5p < "$logfile" | cut -d',' -f1 | cut -d' ' -f2)"
			echo "      Lockfile: $lockfile"
			echo "      See --help on how to stop it"
			queue add end
		fi
	fi
	# allocate pids
	echo >> "$lockfile" # bash pid
	echo >> "$lockfile" # lftp transfer pid
	echo >> "$lockfile" # bash progress pid
	echo >> "$lockfile" # lftp process pid
	echo >> "$lockfile" # speedaverage
	sed "1c $BASHPID" -i "$lockfile"
	echo "INFO: Process id: $BASHPID"
}

function main {
	#setting paths
	filepath="$1"
	transfer_path="$filepath"
	orig_name=$(basename "$filepath")
	# if filepath is a file, correct temppath
	if [[ -f "$filepath" ]]; then
		tempdir="$scriptdir/run/$username-temp/${orig_name%.*}-temp/"
	elif [[ -d "$filepath" ]]; then
		tempdir="$scriptdir/run/$username-temp/${orig_name}-temp/"
	fi
	ScriptStartTime=$(date +%s)
	echo "INFO: Process start-time: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "INFO: Preparing transfer: $filepath"
	echo "INFO: Lunched from: $source"

	#add to queue file, to get ID initialized
	queue add
	echo "INFO: Simultaneous transfers: $parallel"
	#Checking transferesize
	get_size "$filepath"
	#Execute preexternal command
	if [[ -n "$exec_pre" ]]; then
		if [[ $test_mode != "true" ]]; then
			echo "INFO: Executing external command - START"
			echo "      $exec_pre"
			eval "$exec_pre" | (while read; do echo "      $REPLY"; done)
		else
			echo -e "\e[00;31mTESTMODE: Would execute external command: \"$exec_pre\"\e[00m"
		fi
	echo "INFO: Executing external command - ENDED"
	fi

	#Prepare login
	loadDependency DFtpLogin && ftp_login 1

	#confirm server is online
	if [[ $confirm_online == "true" ]]; then
		loadDependency DFtpOnlineTest && online_test
	fi

	#Check if enough free space on ftp
	if [[ "$ftpsizemanagement" == "true" ]]; then
		if [[ $transferetype == "upftp" ]]; then
			loadDependency DFtpSizeManagement && ftp_sizemanagement check
		elif [[ $transferetype == "downftp" ]]; then
			freesize=$(( $(df -P "$ftpincomplete" | tail -1 | awk '{ print $3}') / (1024*1024) ))
			freespaceneeded="$size"
			while [[ "$freesize" -lt "$freespaceneeded" ]]; do
				echo "INFO: Not enough free space"
				echo "INFO: Trying again in 1 min"
				sleep 60
				# recalculate free space
				freesize=$(( $(df -P "$ftpincomplete" | tail -1 | awk '{ print $3}') / (1024*1024) ))
			done
		fi
	fi

	## Sendoption
	echo "INFO: Sendoption: $send_option"
	#Is largest file too large
	if [[ "$send_option" == "split" ]]; then
		if [[ -n $(builtin type -p rar) ]] || [[ -n $(builtin type -p cksfv) ]]; then
			if [[ $transferetype == "upftp" ]]; then
				loadDependency DLargeFile && largefile "$filepath" "exclude_array[@]"
			elif [[ $transferetype == "downftp" ]]; then
				echo -e "\e[00;33mERROR: send_option=split is not supported in mode=$transferetype. Exiting ...\e[00m"
				cleanup session; cleanup end
				echo -e "INFO: Program has ended\n"
				exit 1
			fi
		else
			echo -e "\e[00;33mERROR: send_option=split is not supported as rar or cksfv is missing. Exiting ...\e[00m"
			cleanup session; cleanup end
			echo -e "INFO: Program has ended\n"
			exit 1
		fi
	# Try to only send videofile
	elif [[ "$send_option" == "video" ]]; then
		if [[ -n $(builtin type -p rar2fs) ]]; then
			if [[ $transferetype == "upftp" ]]; then
				loadDependency DVideoFile && videoFile
			elif [[ $transferetype == "downftp" ]]; then
				echo -e "\e[00;33mERROR: send_option=video is not supported in mode=$transferetype. Exiting ...\e[00m"
				cleanup session; cleanup end
				echo -e "INFO: Program has ended\n"
				exit 1
			fi
		else
			echo -e "\e[00;33mERROR: send_option=video is not supported as rarfs is missing. Exiting ...\e[00m"
			cleanup session; cleanup end
			echo -e "INFO: Program has ended\n"
			exit 1
		fi
	fi

	# Try to sort files
	if [[ "$sort" == "true" ]] || [[ -n "$sortto" ]]; then
		loadDependency DSort && sortFiles "$sortto"
	fi

	# Delay transfer if needed
	delay

	# Transfer files
	ftp_transfere

	# Checking for remaining space
	if [[ "$ftpsizemanagement" == "true" ]] && [[ $failed != true ]]; then
		ftp_sizemanagement info # already loaded previously
	fi

	# Update logfile
	if [[ $failed != true ]]; then
		logrotate
	fi

	# Clean up current session
	cleanup session

	#send push notification
	if [[ -n $push_user ]]; then
		if [[ $test_mode ]]; then
			echo -e "\e[00;31mTESTMODE: Would send notification \""$orig_name" "Sendoption=$send_option Size=$size MB Time=$transferTime2 Average speed=$SpeedAverage MB/s Path=$ftpcomplete"\" to token=$push_token and user=$push_user \e[00m"
		elif [[ $failed == true ]]; then
			loadDependency DPushOver && Pushover "Failed: $orig_name" "Sendoption:        $send_option
Size:                     $size MB
Path:                    $ftpcomplete"
		else
		loadDependency DPushOver && Pushover "$orig_name" "Sendoption:        $send_option
Size:                     $size MB
Time:                   $transferTime2
Average speed: $SpeedAverage MB/s
Path:                    $ftpcomplete"
		fi
	fi

	#Execute external command
	if [[ -n $exec_post ]] && [[ $failed != true ]]; then
		if [[ $test_mode != "true" ]]; then
			if [[ $allow_background == "true" ]]; then
				echo "INFO: Executing external command(In background) - START"
				echo "      $exec_post"
				eval $exec_post &
			else
				echo "INFO: Executing external command - START:"
				echo "      $exec_post"
				eval $exec_post | (while read; do echo "      $REPLY"; done)
				echo "INFO: Executing external command - ENDED"
			fi
		else
			echo -e "\e[00;31mTESTMODE: Would execute external command: \"$exec_post\"\e[00m"
		fi
	fi

	# final
	ScriptEndTime=$(date +%s)
	TotalTransferTime=$(( $ScriptEndTime - $ScriptStartTime ))
	if [[ $failed == true ]]; then
		echo -e "\e[00;37mINFO: \e[00;31mTransfere failed\e[00m"
	else
		echo -e "\e[00;37mINFO: \e[00;32mTransfere finished\e[00m"
	fi
	echo "                       Name: $orig_name"
	echo "                       Size: $size MB"
	echo "                      Speed: $SpeedAverage MB/s"
	echo "              Transfer time: $transferTime2"
	echo "                 Start time: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "                   End time: $(date --date=@$ScriptEndTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "                 Total time: $(printf '%02dh:%02dm:%02ds' "$(($TotalTransferTime/(60*60)))" "$((($TotalTransferTime/60)%60))" "$(($TotalTransferTime%60))")"

	# Remove finished one
	if [[ $failed != true ]]; then
		queue remove
	fi
	# Run queue
	queue next
}

function start_main {
	#Look for which options has been used
	while :; do
		case "$1" in
		--path=* ) filepath="${1#--path=}"; shift;;
		--user=* ) user="${1#--user=}"; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; shift;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; shift;;
		--delay=* ) delay="${1#--delay=}"; shift;;
		--force | -f ) force=true; shift;;
		--queue ) queue=true; shift;;
		--source=* ) source="${1#--source=}"; shift;;
		--sortto=* ) sortto="${1#--sortto=}"; shift;;
		--test ) test_mode="true"; echo "INFO: Running in TESTMODE, no changes are made!"; shift;;
		* ) break ;;
		--) shift; break;;
		esac
	done

	# main program starts here

	# confirm filepath
	if [[ -z "$filepath" ]]; then
		# if --path is not used, try and run queue
		queue next
	elif [[ -z "$(find "$filepath" -type d 2>/dev/null)" ]] && [[ -z "$(find "$filepath" -type f -print | head -n 1 2>/dev/null)" ]] || [[ -z "$(find "$filepath" -type f -print | head -n 1 2>/dev/null)" ]]; then
		# path with files or file not found
		if [[ "$transferetype" == "downftp" ]] || [[ "$transferetype" == fxp ]]; then
			# server <-- client, assume path is OK - we will know for sure when size is found
			true
		elif [[ "$transferetype" == "upftp" ]]; then
			# server --> client
			echo -e "\e[00;31mERROR: Option --path is required with existing path (with file(s)), or file does not exists:\n $filepath\n This cannot be transfered!\e[00m\n"
			exit 1
		else
			echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Have a look on your config (--user=$user --edit)!\e[00m\n"
			exit 1
		fi
	fi
	# Save transfer to queue and exit
	if [[ $queue == true ]]; then
		queue add end
	fi

	# Create lockfile
	if [[ "$lockfileRunning" == "true" ]]; then
		echo "INFO: Updating lockfile"
	else
		lockfile
	fi

	echo "INFO: Transfer-option: $transferetype"

	#Load dependencies
	loadDependency DSetup

	# Load user config
	loadConfig

	# OK nothing running and --path is real, lets continue
	# fix spaces: "/This\ is\ a\ path"
	# Note: The use of normal backslashes is NOT supported
	filepath="$(echo "$filepath" | sed 's/\\./ /g')"

	#start program
	main "$filepath"
}
