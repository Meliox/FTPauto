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
	# Queue system: If something is already running for the user, add it to the queue.
	local option i old_id
	option=$2
	case "$1" in
		"add" )
			if [[ $queue_running == true ]]; then
				# Task has been started from queue, no need to add it.
				true
			else
				# Figure out ID.
				id_old=$id
				if [[ -e "$queue_file" ]]; then
					# Get last ID.
					id=$(( $(tail -1 "$queue_file" | cut -d'|' -f1) + 1 ))
				else
					# Assume this is the first one.
					id="1"
				fi
				get_size "$filepath" &> /dev/null
				if [[ -e "$queue_file" ]] && [[ -n $(cat "$queue_file" | grep "$filepath") ]] && [[ -z $option ]]; then
					# Passing an item which is already in the queue, do nothing.
					echo -e "INFO: Item already in queue. Doing nothing...\n"
					exit 0
				elif [[ "$option" == failed ]]; then
					# Passing a failed item, remove it, and add it with the status failed.
					failed="true"
					# Remove ID from queue.
					sed "/^"$id_old"/d" -i "$queue_file"
					echo "$id|$source|$filepath|$sortto|${size}MB|true|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
					echo -e "\e[00;33mINFO: Failing item: $(basename "$filepath")\e[00m"
				elif [[ "$option" == end ]]; then
					# Passed item should only be queued, then exit.
					source="${source}Q"
					echo "$id|$source|$filepath|$sortto|${size}MB|false|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
					echo -e "INFO: Queueing: $(basename "$filepath"), id=$id\n"
					exit 0
				else
					# Passed item should be queued, e.g. when something already is being transferred.
					echo "INFO: Queueid: $id"
					echo "$id|$source|$filepath|$sortto|${size}MB|false|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
				fi
			fi
			;;
		"remove" )
			# Remove item according to ID.
			sed "/^"$id"/d" -i "$queue_file"
			# If queue is true then continue to run else stop.
			if [[ $continue_queue == true ]]; then
				queue next
			else
				cleanup end
			fi
			;;
		"next" )
			# Process next item in queue from top.
			if [[ -f "$queue_file" ]] && [[ -n $(cat "$queue_file") ]]; then
				i="1"
				failed="true"
				# Look for non-failed items.
				while [[ $failed == true ]]; do
					# Load next item from top.
					id=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $1}' "$queue_file")
					# Check if ID has failed.
					failed=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $6}' "$queue_file")
					let i++
				done
				if [[ $failed == false ]]; then
					# Found a non-failed item, which will be downloaded.
					i=$(grep -n "^${id}|" "$queue_file" | grep -Eo '^[^:]+')
					source=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $2}' "$queue_file")
					filepath=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $3}' "$queue_file")
					sort=$(awk 'BEGIN{FS="|";OFS=" "}NR=='$i'{print $4}' "$queue_file")
					# Execute main script again.
					queue_running="true"
					if [[ -f "$lockfile" ]]; then
						# Ensure that lockfile isn't created running queue.
						lockfileRunning="true"
					fi
					echo "---------------------- Running queue ----------------------"
					echo "Transfering id=$id, $(basename "$filepath")"
					start_main --path="$filepath" --user="$username" --sortto="$sort"
				else
					# All items in the queue are marked as failed, e.g. nothing to transfer.
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
					echo -e "\nINFO: Queue does not contain non-failed items. Program will end\n"
					cleanup end
					exit 1
				fi
			else
				# No queuefile found, e.g. nothing to transfer.
				echo "----------------------- Empty queue -----------------------"
				if [[ -f "$queue_file" ]]; then rm "$queue_file"; fi
				echo -e "INFO: Queue is empty. Program will end\n"
				cleanup end
				exit 0
			fi
			;;
                "fail" )
                # Failed item, remove it, and add it with the status failed.
                # Remove ID from queue.
                sed "/^"$id"/d" -i "$queue_file"
                echo "$id|$source|$filepath|$sortto|${size}MB|true|$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
                echo -e "\e[00;33mINFO: Failing item: $(basename "$filepath")\e[00m"
                ;;
	esac
}

function transfer_process {
	# used to start and stop the lftp transfer and progressbar
	local pid_f_process
	case "$1" in
		"start" ) #start progressbar and transfer
			TransferStartTime=$(date +%s)
			transfer_process_bar &
			pid_f_process=$!
			sed "3c $pid_f_process" -i "$lockfile"
			echo -e "\e[00;37mINFO: \e[00;32mTransfer started: $(date --date=@$TransferStartTime '+%d/%m/%y-%a-%H:%M:%S')\n\e[00m"
			$lftp -f "$transfere_file" &> /dev/null &
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

function transfer {
	local lftp_exclude quittime waittime

	# Prepare new transfer
	{
		# Fail transfer is any command fails
		echo "set cmd:fail-exit true" >> "$transfere_file"

		# Write regexp to config for directory transfers
		if [[ "${#exclude_array[@]}" -gt 0 && -n "${exclude_array[@]}" && ($transfer_type = "directory" || -d "$transfer_path") ]]; then
			for ((i=0; i<${#exclude_array[@]}; i++)); do
				[[ $i -gt 0 ]] && lftp_exclude+="|"
				lftp_exclude+="^.*${exclude_array[i]}*"
			done
			lftp_exclude+="\$"
			echo "set mirror:exclude-regex \"$lftp_exclude\"" >> "$transfere_file"
			echo "set mirror:no-empty-dirs true" >> "$transfere_file"
		fi

		if [[ $transferetype == "downftp" ]]; then
			# Handle lftp transfer for downftp
				cat "$ftplogin_file1" >> "$transfere_file"
				# Create final directories if they don't exist
				echo "!mkdir -p \"${ftpcomplete}\"" >> "$transfere_file"
				[[ -n $ftpincomplete ]] && echo "!mkdir -p \"${ftpincomplete}\"" >> "$transfere_file"
				echo "set cmd:fail-exit true" >> "$transfere_file"

				# Determine transfer type (file or directory)
				if [[ $transfer_type = file ]]; then
					[[ -n $ftpincomplete ]] && echo "queue get -c -O \"${ftpincomplete}\" \"${transfer_path}\"" >> "$transfere_file"
					[[ -z $ftpincomplete ]] && echo "queue get -c -O \"${ftpcomplete}\" \"${transfer_path}\"" >> "$transfere_file"
				elif [[ $transfer_type = directory ]]; then
					[[ -n $ftpincomplete ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c \"${transfer_path}\" \"${ftpincomplete}\"" >> "$transfere_file"
					[[ -z $ftpincomplete ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c \"${transfer_path}\" \"${ftpcomplete}\"" >> "$transfere_file"
				fi

				echo "wait" >> "$transfere_file"

				# Move files locally if ftpincomplete directory is used
				[[ -n $ftpincomplete ]] && echo "queue !mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$transfere_file"
				echo "wait" >> "$transfere_file"
		elif [[ $transferetype == "upftp" ]]; then
			# Handle lftp transfer for upftp
			cat "$ftplogin_file1" >> "$transfere_file"
			echo "mkdir -p \"${ftpcomplete}\"" >> "$transfere_file"
			[[ -n "${ftpincomplete}" ]] && echo "mkdir -p \"${ftpincomplete}\"" >> "$transfere_file"
			echo "set cmd:fail-exit true" >> "$transfere_file"

			# Determine transfer type (file or directory)
			if [[ -f "$transfer_path" ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue put -c -O \"$ftpincomplete\" \"${transfer_path}\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue put -c -O \"$ftpcomplete\" \"${transfer_path}\"" >> "$transfere_file"
			elif [[ -d "$transfer_path" ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpincomplete}\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpcomplete}\"" >> "$transfere_file"
			fi

			echo "wait" >> "$transfere_file"

			# Move files remotely if ftpincomplete directory is used
			[[ -n "$ftpincomplete" ]] && echo "queue mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$transfere_file"
			echo "wait" >> "$transfere_file"
		elif [[ $transferetype == "fxp" ]]; then
			# Handle lftp transfer for fxp
			server_login 2
			cat "$ftplogin_file2" >> "$transfere_file"
			echo "mkdir -p \"$ftpcomplete\"" >> "$transfere_file"
			[[ -n $ftpincomplete ]] && echo "mkdir -p \"$ftpincomplete\"" >> "$transfere_file"
			echo "set cmd:fail-exit true" >> "$transfere_file"

			# Determine transfer type (file or directory)
			if [[ $transfer_type = file ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue get -c ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"$transfer_path\" -o ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"$ftpincomplete\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue get -c ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"$transfer_path\" -o ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"$ftpcomplete\"" >> "$transfere_file"
			elif [[ $transfer_type = directory ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"${transfer_path}\" ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"${ftpincomplete}\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL ftp://$ftpuser1:$ftppass1@$ftphost1:$ftpport1:\"${transfer_path}\" ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"${ftpcomplete}\"" >> "$transfere_file"
			fi

			echo "wait" >> "$transfere_file"

			 # Move files remotely if ftpincomplete directory is used
			[[ -n "$ftpincomplete" ]] && echo "queue mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$transfere_file"
			echo "wait" >> "$transfere_file"
		elif [[ $transferetype == "upsftp" ]]; then
			# handle sftp transfer
			cat "$sftplogin_file" >> "$transfere_file"

			# Create final directories if they don't exist
			echo "!mkdir -p \"${ftpcomplete}\"" >> "$transfere_file"

			[[ -n "${ftpincomplete}" ]] && echo "mkdir -p \"${ftpincomplete}\"" >> "$transfere_file"

			# Determine transfer type (file or directory)
			if [[ -f "$transfer_path" ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue put -c -O \"$ftpincomplete\" \"${transfer_path}\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue put -c -O \"$ftpcomplete\" \"${transfer_path}\"" >> "$transfere_file"
			elif [[ -d "$transfer_path" ]]; then
				[[ -n "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpincomplete}\"" >> "$transfere_file"
				[[ -z "$ftpincomplete" ]] && echo "queue mirror --no-umask -p --parallel=$parallel -c -RL \"${transfer_path}\" \"${ftpcomplete}\"" >> "$transfere_file"
			fi

			echo "wait" >> "$transfere_file"

			# Move files remotely if ftpincomplete directory is used
			[[ -n "$ftpincomplete" ]] && echo "queue mv \"${ftpincomplete}${orig_name}\" \"${ftpcomplete}\"" >> "$transfere_file"
			echo "wait" >> "$transfere_file"
		else
			echo -e "\e[00;31mERROR: Transfer setting not recognized\e[00m\n"
			cleanup die
		fi

		echo "quit" >> "$transfere_file"
	}

	# Start transferring
	{
		if [[ $test_mode != "true" ]]; then
			# Start the transfer process
			transfer_process start
			
			# Loop until transfer completes or timeout is reached
			while [[ $pid_transfer_status -ne 0 ]]; do
				quittime=$(( ScriptStartTime + retry_download_max*60 ))
				
				# Check if it's time to quit
				if [[ $(date +%s) -gt $quittime ]]; then
					echo -e "\e[00;31mERROR: Transfer failed after reaching the maximum retry time ($retry_download_max minutes)!\e[00m"
					
					# Stop the transfer process and add to queue
					transfer_process "stop-process-bar"
					queue add failed
					break
				else
					echo -e "\e[00;31mERROR: Transfer failed for some reason!\e[00m"
					echo "INFO: Retrying until $(date --date=@$quittime '+%d/%m/%y-%a-%H:%M:%S')"
					
					# Stop the transfer process, pause session, and retry after a delay
					transfer_process "stop-process-bar"
					echo "INFO: Pausing session and trying again in 60 seconds"
					sed "3s#.*#***************************	FTP INFO: DOWNLOAD POSTPONED! Trying again in ${retry_download} minutes#" -i "$logfile"
					sleep 60
					transfer_process start
				fi
			done
			
			# Stop the transfer process and display end message
			transfer_process "stop-process-bar"
			echo -e "\n\e[00;37mINFO: \e[00;32mTransfer ended: $(date --date=@$TransferEndTime '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
		else
			# Test mode: Display the lftp commands that would be executed
			echo -e "\e[00;31mTESTMODE: LFTP-transfer NOT STARTED\e[00m"
			echo "Would execute the following in lftp:"
			cat "$transfere_file" | (while read; do echo "      $REPLY"; done)
		fi
	}
}

# Function to show the progress of the transfer
function transfer_process_bar {
    if [[ $test_mode != "true" ]]; then
        sleep 5 # Wait for transfer to start
        
        if [[ $transferetype == "downftp" ]]; then
            # Get the transferred size for download FTP
            transfered_size="du -s \"$ftpincomplete$changed_name\" > \"$proccess_bar_file\""
            if [[ $transfer_type = file ]]; then
                echo "du -s \"$ftpincomplete${orig_name}\" > ~/../..$proccess_bar_file" >> "$transfere_processbar"
            elif [[ $transfer_type = directory ]]; then
                echo "du -s \"$ftpincomplete$orig_name\" > ~/../..$proccess_bar_file" >> "$transfere_processbar"
            fi
        elif [[ $transferetype == "upftp" || $transferetype == "fxp" ]]; then
            # Create a config file for lftp process bar
            cat "$ftplogin_file1" >> "$transfere_processbar"
            # Determine whether it's a file or directory
            if [[ -f "$filepath" ]]; then
                echo "du -s \"$ftpincomplete${orig_name}\" > ~/../..$proccess_bar_file" >> "$transfere_processbar"
            elif [[ -d "$filepath" ]]; then
                echo "du -s \"$ftpincomplete$orig_name\" > ~/../..$proccess_bar_file" >> "$transfere_processbar"
            fi
            echo "quit" >> "$transfere_processbar"
        fi
        
        # Run the process bar loop
        while :; do
            if [[ $transferetype == "downftp" ]]; then
                eval $transfered_size
            elif [[ $transferetype == "upftp" || $transferetype == "fxp" ]]; then
                $lftp -f "$transfere_processbar" &> /dev/null &
                pid_process=$!
                sed "4c $pid_process" -i "$lockfile"
                wait $pid_process
            fi
            
            # Get current time and transferred information
            if [[ ! -a "$proccess_bar_file" ]]; then
                continue
            elif [[ -z "$TransferredOld" ]] && [[ -a "$proccess_bar_file" ]]; then
                TransferredOld=$(cat $proccess_bar_file | awk '{print $1}')
                ProgressTimeOld=$(date +%s)
                rm "$proccess_bar_file"
                continue
            fi
            
            # Feedback received
            if [[ -a "$proccess_bar_file" ]]; then
                ProgressTimeNew=$(date +%s)
                TransferredNew=$(cat "$proccess_bar_file" | awk '{print $1}')
                TransferredNewMB=$(echo $TransferredNew / 1024 | bc)
                TotalTimeDiff=$(( ProgressTimeNew - TransferStartTime ))
                TimeDiff=$(printf '%02dh:%02dm:%02ds' "$((TotalTimeDiff/(60*60)))" "$(((TotalTimeDiff/60)%60))" "$((TotalTimeDiff%60))")
                
                if [[ "$(( $TransferredNew - $TransferredOld ))" -ge "1" ]] && [[ "$(( $TransferredNew - $TransferredOld ))" =~ ^[0-9]+$ ]]; then
                    percentage=$(echo "scale=4; ( $TransferredNew / ( $directorysize / ( 1024 ) ) ) * 100" | bc)
                    percentage=$(echo $percentage | sed 's/\(.*\)../\1/')
                    speed=$(echo "scale=2; ( ($TransferredNew - $TransferredOld) / 1024 ) / ( $ProgressTimeNew - $ProgressTimeOld )" | bc)
                    eta=$(echo "( ($directorysize / 1024 ) - $TransferredNew ) / ($speed * 1024 )" | bc)
                    etatime=$(printf '%02dh:%02dm:%02ds' "$(($eta/(60*60)))" "$((($eta/60)%60))" "$(($eta%60))")
                    
                    SpeedOld+=( "$speed" )
                    if [[ -n "${#SpeedOld[@]}" ]]; then
                        sum="0"
                        for i in "${SpeedOld[@]}"; do
                            sum=$(echo "( $sum + $i )" | bc)
                        done
                        SpeedAverage=$(echo "scale=2; $sum / ${#SpeedOld[@]}" | bc)
                        sed "5c $SpeedAverage" -i "$lockfile"
                        tput cuu 1
                        tput el1
                    fi
                else
                    speed="?"
                    SpeedAverage="?"
                    percentage="0"
                    etatime="?"
                fi
                
                # Update file and output the current line
                sed "5s#.*#***************************	Transferring: ${orig_name}, $percentage\%, in $TimeDiff, $speed MB/s(current), ETA: $etatime, ${SpeedAverage} MB/s (avg)   #" -i "$logfile"
                cols=$(($(tput cols) - 2))
                percentagebarlength=$(echo "scale=0; $percentage * $cols / 100" | bc)
                string="$(eval printf "=%.0s" '{1..'"$percentagebarlength"\})"
                string2="$(eval printf "\ %.0s" '{1..'"$(($cols - $percentagebarlength - 1))"\})"
                
                if [[ $percentagebarlength -eq 0 ]]; then
                    printf "\r[$string2]      (no transferred information yet) ($(date '+%H:%M:%S'))"
                elif [[ $(echo "scale=0; $cols - $percentagebarlength - 1" | bc) -eq 0 ]]; then
                    printf "\r[$string>]      $percentage%% ETA ${etatime}@${speed}MB/s. ${TransferredNewMB}MB@${SpeedAverage}MB/s(avg). ($(date '+%H:%M:%S'))"
                else
                    printf "\r[$string>$string2]      $percentage%% ETA ${etatime}@${speed}MB/s. ${TransferredNewMB}MB@${SpeedAverage}MB/s(avg). ($(date '+%H:%M:%S'))"
                fi
            fi
            
            # Update variables and wait
            TransferredOld="$TransferredNew"
            ProgressTimeOld="$ProgressTimeNew"
            rm "$proccess_bar_file"
            sleep $sleeptime
        done
    else
        echo -e "\e[00;31mTESTMODE: LFTP-processbar NOT STARTED\e[00m"
    fi
}

# Function to rotate and manage logs
function logrotate {
	# Check if test mode is not enabled
	if [[ $test_mode != "true" ]]; then
		# Calculate transfer time
		transferTime=$(( $TransferEndTime - $TransferStartTime ))
		transferTime2=$(printf '%02dh:%02dm:%02ds' "$(($transferTime/(60*60)))" "$((($transferTime/60)%60))" "$(($transferTime%60))")

		# Get average speed from lockfile
		SpeedAverage=$(sed -n 5p "$lockfile")

		# Add new info to 7th line of logfile
		sed "7i $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')|${source}|${orig_name}|${size}MB|${transferTime2}|${SpeedAverage}MB/s" -i "$logfile"
		lognumber=$((7 + $lognumber ))

		# Add text to oldlogfile if log rotation is enabled
		if [[ $logrotate == "true" ]]; then
			if [[ -n $(sed -n $lognumber,'$p' "$logfile") ]]; then
				sed -n $lognumber,'$p' "$logfile" >> "$oldlogfile"
			fi
		fi

		# Remove text from old file
		if [ "$lognumber" -ne 0 ]; then
			sed $lognumber,'$d' -i "$logfile"
		fi

		# Calculate total downloaded size
		totaldl=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f4)
		totaldl=${totaldl%MB}
		if [[ -z "$totaldl" ]]; then
			totaldl="0"
		fi
		totaldl=$(echo "$totaldl + $size" | bc)

		# Increment total number of transfers
		totalrls=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f6)
		totalrls=$(echo "$totalrls + 1" | bc)

		# Calculate total download time
		totaldltime=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' "$logfile" | cut -d' ' -f10)
		totaldltime_seconds=$(awk 'BEGIN{split("'$totaldltime'",a,":"); print a[1]*(60*60*24)+a[2]*(60*60)+a[3]*60+a[4];}')
		totaldltime=$(echo "$totaldltime_seconds + $transferTime" | bc)
		totaldltime=$(printf '%02dd:%02dh:%02dm:%02ds' "$(($totaldltime/(60*60*24)))" "$(($totaldltime/(60*60)%24))" "$((($totaldltime/60)%60))" "$(($totaldltime%60))")

		# Update logfile header and stats
		sed "1s#.*#*****  FTPauto ${s_version}#" -i "$logfile"
		sed "2s#.*#*****  STATS: ${totaldl}MB in ${totalrls} transfers in ${totaldltime}#" -i "$logfile"
		sed "3s#.*#*****  FTP INFO: N/A#" -i "$logfile"
		sed "4s#.*#*****  LASTDL: $(date)|${orig_name}|${SpeedAverage}MB/s#" -i "$logfile"
		sed "5s#.*#*****  #" -i "$logfile"
	else
		# If test mode, just print message
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
    # Check if lockfile exists and process is still running
    if [[ -f "$lockfile" ]] && [[ $force != "true" ]]; then
        # Lockfile exists, check if process is still running
        mypid_script=$(sed -n 1p "$lockfile")
        mypid=$(sed -n 2p "$lockfile")
        alreadyinprogress=$(sed -n 3p "$lockfile")

        # Check if the script process is still running
        kill -0 $mypid_script &> /dev/null
        if [[ $? -eq 1 ]]; then
            # Process is not running, continue
            echo "INFO: Old lockfile found, but process is not running"
            rm -f "$lockfile"
        else
            # Process is still running, display information and exit
            echo "INFO: Another instance of the script is already running:"
            echo "      Script PID: $mypid_script"
            echo "      Transfer PID: $alreadyinprogress"
            echo "      Transfer: $(sed -n 5p < "$logfile" | cut -d',' -f1 | cut -d' ' -f2)"
            echo "      Lockfile: $lockfile"
            echo "      Use --help to learn how to stop it"
            queue add end
            return
        fi
    fi

    # Allocate PIDs and update lockfile
    echo "$BASHPID" >> "$lockfile" # Bash PID
    echo >> "$lockfile" # LFTP transfer PID (to be allocated later)
    echo >> "$lockfile" # Bash progress PID (to be allocated later)
    echo >> "$lockfile" # LFTP process PID (to be allocated later)
    echo >> "$lockfile" # Speed average (to be calculated later)

    echo "INFO: Process ID: $BASHPID"
}

function main {
	# Set paths
	filepath="$1"
	transfer_path="$filepath"
	orig_name=$(basename "$filepath")

	# Define temp directory based on file type
	if [[ -f "$filepath" ]]; then
		tempdir="$scriptdir/run/$username-temp/${orig_name%.*}-temp/"
	elif [[ -d "$filepath" ]]; then
		tempdir="$scriptdir/run/$username-temp/${orig_name}-temp/"
	fi

	# Record script start time and display relevant information
	ScriptStartTime=$(date +%s)
	echo "INFO: Process start-time: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "INFO: Preparing transfer: $filepath"
	echo "INFO: Launched from: $source"

	# Add to queue file to initialize ID
	queue add
	echo "INFO: Simultaneous transfers: $parallel"

	# Check transfer size
	get_size "$filepath"

	# Execute pre-external command if specified
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

	# Prepare login based on transfer type
	if [[ "$transferetype" == "upftp" || "$transferetype" == "downftp" || "$transferetype" == "fxp" ]]; then
		loadDependency DServerLogin && ftp_login 1
	elif [[ "$transferetype" == "upsftp" ]]; then
		loadDependency DServerLogin && sftp_login 1
	fi

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

	# Check send option
	echo "INFO: Send option: $send_option"
	if [[ "$send_option" == "split" ]]; then
		# Check if rar or cksfv is available
		if [[ -n $(command -v rar) || -n $(command -v cksfv) ]]; then
			# Check transfer type
			if [[ "$transferetype" == "upftp" ]]; then
				loadDependency DLargeFile && largefile "$filepath" "exclude_array[@]"
			elif [[ "$transferetype" == "downftp" ]]; then
				echo -e "\e[00;33mERROR: send_option=split is not supported in mode=$transferetype. Exiting ...\e[00m"
				cleanup session
				cleanup end
				echo -e "INFO: Program has ended\n"
				exit 1
			fi
		else
			echo -e "\e[00;33mERROR: send_option=split is not supported as rar or cksfv is missing. Exiting ...\e[00m"
			cleanup session
			cleanup end
			echo -e "INFO: Program has ended\n"
			exit 1
		fi
	elif [[ "$send_option" == "video" ]]; then
		# Check if rar2fs is available
		if [[ -n $(command -v rar2fs) ]]; then
			# Check transfer type
			if [[ "$transferetype" == "upftp" ]]; then
				loadDependency DVideoFile && videoFile
			elif [[ "$transferetype" == "downftp" ]]; then
				echo -e "\e[00;33mERROR: send_option=video is not supported in mode=$transferetype. Exiting ...\e[00m"
				cleanup session
				cleanup end
				echo -e "INFO: Program has ended\n"
				exit 1
			fi
		else
			echo -e "\e[00;33mERROR: send_option=video is not supported as rarfs is missing. Exiting ...\e[00m"
			cleanup session
			cleanup end
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
	transfer

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

	# Send push notification if push user is specified
	if [[ -n $push_user ]]; then
		if [[ $test_mode ]]; then
			# Display notification details in test mode
			echo -e "\e[00;31mTESTMODE: Would send notification \""$orig_name" "Sendoption=$send_option Size=$size MB Time=$transferTime2 Average speed=$SpeedAverage MB/s Path=$ftpcomplete"\" to token=$push_token and user=$push_user \e[00m"
		elif [[ $failed == true ]]; then
			# Send notification if transfer failed
			loadDependency DPushOver && Pushover "Failed: $orig_name" "Sendoption:        $send_option
	Size:                     $size MB
	Path:                    $ftpcomplete"
		else
			# Send notification if transfer succeeded
			loadDependency DPushOver && Pushover "$orig_name" "Sendoption:        $send_option
	Size:                     $size MB
	Time:                   $transferTime2
	Average speed: $SpeedAverage MB/s
	Path:                    $ftpcomplete"
		fi
	fi

	# Execute external command if specified and transfer did not fail
	if [[ -n $exec_post ]] && [[ $failed != true ]]; then
		if [[ $test_mode != "true" ]]; then
			if [[ $allow_background == "true" ]]; then
				# Execute command in background if allowed
				echo "INFO: Executing external command (in background) - START"
				echo "      $exec_post"
				eval $exec_post &
			else
				# Execute command and display output
				echo "INFO: Executing external command - START:"
				echo "      $exec_post"
				eval $exec_post | (while read; do echo "      $REPLY"; done)
				echo "INFO: Executing external command - ENDED"
			fi
		else
			# Display the command that would be executed in test mode
			echo -e "\e[00;31mTESTMODE: Would execute external command: \"$exec_post\"\e[00m"
		fi
	fi

	# Finalize transfer and display summary
	ScriptEndTime=$(date +%s)
	TotalTransferTime=$(( $ScriptEndTime - $ScriptStartTime ))
	if [[ $failed == true ]]; then
		# Display transfer failure message
		echo -e "\e[00;37mINFO: \e[00;31mTransfer failed\e[00m"
	else
		# Display transfer success message
		echo -e "\e[00;37mINFO: \e[00;32mTransfer finished\e[00m"
	fi
	echo "                       Name: $orig_name"
	echo "                       Size: $size MB"
	echo "                      Speed: $SpeedAverage MB/s"
	echo "              Transfer time: $transferTime2"
	echo "                 Start time: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "                   End time: $(date --date=@$ScriptEndTime '+%d/%m/%y-%a-%H:%M:%S')"
	echo "                 Total time: $(printf '%02dh:%02dm:%02ds' "$(($TotalTransferTime/(60*60)))" "$((($TotalTransferTime/60)%60))" "$(($TotalTransferTime%60))")"

	# Remove completed item from the queue
	if [[ $failed != true ]]; then
		queue remove
	fi

	# Move to the next item in the queue
	queue next
}

function start_main {
    # Parse command-line options
    while [[ "$1" ]]; do
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
        esac
    done

    # Main program starts here

    # Confirm filepath
    if [[ -z "$filepath" ]]; then
        # If --path is not used, try to run from the queue
        queue next
    elif [[ -z "$(find "$filepath" -type d 2>/dev/null)" ]] && [[ -z "$(find "$filepath" -type f -print | head -n 1 2>/dev/null)" ]] || [[ -z "$(find "$filepath" -type f -print | head -n 1 2>/dev/null)" ]]; then
        # Path with files or file not found
        if [[ "$transferetype" == "downftp" || "$transferetype" == "fxp" ]]; then
            # Server <-- Client: Assume path is OK, we will know for sure when size is found
            true
        elif [[ "$transferetype" == "upftp" ]]; then
            # Server --> Client: Display error if path not found
            echo -e "\e[00;31mERROR: Option --path is required with an existing path (with file(s)), or file does not exist:\n $filepath\n This cannot be transferred!\e[00m\n"
            queue fail
            queue next
        else
            echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Check your configuration (--user=$user --edit)!\e[00m\n"
            exit 1
        fi
    fi

    # Save transfer to queue and exit
    if [[ $queue == true ]]; then
        queue add end
    fi

    # Create lockfile if not already running
    if [[ "$lockfileRunning" != "true" ]]; then
        lockfile
    else
        echo "INFO: Updating lockfile"
    fi

    echo "INFO: Transfer-option: $transferetype"

    # Load dependencies
    loadDependency DSetup

    # Load user config
    loadConfig

    # Fix spaces in filepath
    filepath="$(echo "$filepath" | sed 's/\\./ /g')"

    # Start main program
    main "$filepath"
}