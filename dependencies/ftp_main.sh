#!/bin/bash
############## CODE STARTS HERE ##################
script="$(readlink -f $0)"
scriptdir=$(dirname $script)
scriptdir=${scriptdir%/dependencies}

function delay {
# if --delay is set, wait until it ends. If start/end time is set in config use them. Delay overrules everything
	if [[ -n $delay ]]; then
		current_epoch=$(date +%s)
		target_epoch=$(date -d "$delay" +%s)
		if [[ $target_epoch -gt $current_epoch ]]; then
			sleep_seconds=$(( $target_epoch - $current_epoch ))
			if [[ $test_mode != "true" ]]; then
				echo "INFO: Transfere has been postponed until $delay"
				timediff=$(printf '%2d:%2d:%2d' "$(($sleep_seconds/(60*60)))" "$((($sleep_seconds/60)%60))" "$(($sleep_seconds%60))")
				countdown "$timediff"
			else
				echo -e "\e[00;31mTESTMODE: Would delay until $delay\e[00m"
			fi
		else
			echo "Error: Time is older than current time, now $(date '+%m/%d/%y %H:%M') vs. delay $delay . Format is mm/dd/yy hh:mm. Delay could not be used."
			cleanup session
			cleanup end
			exit 1
		fi
	elif [[ -n $transfer_start ]] && [[ -n $transfer_end ]] && [[ $force == "false" ]]; then
		tranfere_timeframe
	fi
}

function countdown {
        local OLD_IFS="${IFS}"
        IFS=":"
        local ARR=( $1 )
        local SECONDS=$((  (ARR[0] * 60 * 60) + (ARR[1] * 60) + ARR[2]  ))
        local START=$(date +%s)
        local END=$((START + SECONDS))
        local CUR=$START
        while [[ $CUR -lt $END ]]; do
                CUR=$(date +%s)
                LEFT=$((END-CUR))
                printf "\r%02d:%02d:%02d" \
                        $((LEFT/3600)) $(( (LEFT/60)%60)) $((LEFT%60))
                sleep 1
        done
        IFS="${OLD_IFS}"
        echo "        "
}

function tranfere_timeframe {
	#start/end in format "14:30"
	if [[ "$transfere_start" > $(date +%R) ]] && [[ "$transfere_end" < $(date +%R) ]];  then
		echo "everthing is ok" &> /dev/null
	else
		kill -9 "$pid_transfer"
		sleep_seconds=$(dateDiff -s "$(date +%T)" "$transfere_start+24:00")
		echo "Time is $(date +%R), transfer is postponed until $transfere_start"
		sed "5s#.*#***************************	Transfering: "$orig_name" - waiting to start at $transfere_Start  #" -i $logfile
		sleep $sleep_seconds
		ftp_transfere
	fi
}

function queue {
# queuesystem. If something already is running for the user, add it to queue.
	local option=$2
	case "$1" in
		"add" )
			if [[ $queue_running == "true" ]]; then
				# task has been started from queue, no need to add it
				true
			else
				# figure out ID
				if [[ -e "$queue_file" ]]; then
					#get last id
					id=$(( $(tail -1 "$queue_file" | cut -d'#' -f1) + 1 ))
				else
					#assume this is the first one
					id="1"
				fi
				get_size "$filepath" &> /dev/null
				if [[ -e "$queue_file" ]] && [[ -n $(cat "$queue_file" | grep $(basename "$filepath")) ]]; then
					echo "INFO: Item already in queue. Doing nothing..."
					echo
					exit 0
				elif [[ "$option" == "end" ]]; then
					source=$source"Q"
					echo "INFO: Queueing: $(basename "$filepath"), id=$id"
					echo "$id#$source#$filepath#$size"MB"#$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
					echo
					exit 0
				else
					echo "INFO: Queueid: $id"
					echo "$id#$source#$filepath#$size"MB"#$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
				fi
			fi
		;;
		"remove" )
			#remove item acording to id
			sed "/^"$id"\#/d" -i "$queue_file"
			# if queue is true then continue to run else stop
			if [[ $continue_queue == "true" ]]; then
				queue run
			else
				cleanup end
			fi
		;;
		"run" )
			# change lockfile status
			lockfileoption="running"
			lockfile "$lockfileoption"
			if [[ -f "$queue_file" ]] && [[ -n $(cat "$queue_file") ]]; then
				#load next item from top
				id=$(awk 'BEGIN{FS="|";OFS=" "}NR==1{print $1}' "$queue_file" | cut -d'#' -f1)
				source=$(awk 'BEGIN{FS="|";OFS=" "}NR==1{print $1}' "$queue_file" | cut -d'#' -f2)
				local filepath=$(awk 'BEGIN{FS="|";OFS=" "}NR==1{print $1}' "$queue_file" | cut -d'#' -f3)
				# execute mainscript again
				queue_running="true"
				echo "---------------------- Running queue ----------------------"
				echo "Transfering id=$id, $(basename "$filepath")"
				start_main --path="$filepath" --user="$username"
			else
				echo "----------------------- Empty queue -----------------------"
				if [[ -f "$queue_file" ]]; then rm "$queue_file"; fi
				echo "Program has ended"
				cleanup end
				exit 0
				echo
			fi
		;;
	esac
}

function ftp_transfer_process {
case "$1" in
	"start" ) #start progressbar and transfer
		TransferStartTime=$(date +%s)
		ftp_processbar $retry_option &
		pid_f_process=$!
		sed "3c $pid_f_process" -i "$lockfile"
		echo -e "\e[00;37mINFO: \e[00;32mTransfer started: $(date --date=@$TransferStartTime '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
		$lftp -f "$ftptransfere_file" &> /dev/null &
		pid_transfer=$!
		sed "2c $pid_transfer" -i "$lockfile"
		wait $pid_transfer
		pid_transfer_status="$?"
		TransferEndTime=$(date +%s)
	;;
	"stop-process-bar" )
		kill -9 $pid_f_process &> /dev/null
		kill -9 $(sed -n '4p' $lockfile) &> /dev/null	
	;;
esac
}

function ftp_transfere {
	#Cleanup before writing config
	if [[ -f "$ftptransfere_file" ]]; then rm "$ftptransfere_file"; fi
	#prepare new transfer
	{
	cat "$ftplogin_file" >> "$ftptransfere_file"
	# optional use regexp to exclude files during mirror
	if [[ -n "${exclude_array[@]}" ]]; then
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
		# create final directories if they don't exists
		echo "!mkdir -p \"$ftpcomplete\"" >> "$ftptransfere_file"
		echo "!mkdir -p \"$ftpincomplete\"" >> "$ftptransfere_file"
		# fail if transfers fails
		echo "set cmd:fail-exit true" >> "$ftptransfere_file"
		# from get_size we know if its a file or a path!
		if [[ "$transfer_type" == "file" ]]; then
			if [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]]; then
				echo "!mkdir -p \"$ftpincomplete$changed_name\"" >> "$ftptransfere_file"
				echo "queue get -c -O \"$ftpincomplete$changed_name\" \"$filepath\"" >> "$ftptransfere_file"
			elif [[ -z $ftpincomplete ]] || [[ $retry_option == "complete" ]]; then
				echo "queue get -c -O \"$ftpcomplete$orig_name\" \"$filepath\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
		elif [[ "$transfer_type" == "directory" ]]; then
			if [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c \"$filepath\" \"$ftpincomplete\"" >> "$ftptransfere_file"
			elif [[ -z $ftpincomplete ]] || [[ $retry_option == "complete" ]]; then
				echo "queue mirror --no-umask -p --parallel=$parallel -c \"$filepath\" \"$ftpcomplete\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
		fi
		# moving part, locally
		if [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]]; then
			echo "queue !mv \"$ftpincomplete$filepath\" \"$ftpcomplete\"" >> "$ftptransfere_file"
		elif [[ -z $ftpincomplete ]] || [[ $retry_option == "complete" ]]; then
			echo "queue !mv \"$ftpincomplete$filepath\" \"$ftpcomplete$orig_name\"" >> "$ftptransfere_file"
		fi
		echo "wait" >> "$ftptransfere_file"
	elif [[ $transferetype == "upftp" ]]; then
		# create final directories if they don't exists
		echo "mkdir -p \"$ftpcomplete\"" >> "$ftptransfere_file"
		echo "mkdir -p \"$ftpincomplete\"" >> "$ftptransfere_file"
		# fail if transfers fails. IMPORTANT that it is after mkdir as it will fail if path exists
		echo "set cmd:fail-exit true" >> "$ftptransfere_file"
		# continue, reverse, locale, remote 
		for ((i=0;i<${#filepath[@]};i++)); do
			if [[ ! -d "${filepath[$i]}" ]]; then
				# files
				# make sure that directory only is created once
				if [[ $video_file_to_complete == "true" ]]; then
					echo "queue put -O \"$ftpcomplete${orig_name[$i]}\" \"${filepath[$i]}\"" >> "$ftptransfere_file"
				else
					if [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]]; then
						if [[ $i -eq 0 ]]; then 
							echo "mkdir -p \"$ftpincomplete$changed_name\"" >> "$ftptransfere_file"
						fi
						echo "queue put -c -O \"$ftpincomplete$changed_name\" \"${filepath[$i]}\"" >> "$ftptransfere_file"
					elif [[ -z $ftpincomplete ]] || [[ $retry_option == "complete" ]]; then
						echo "queue put -O \"$ftpcomplete${orig_name[$i]}\" \"${filepath[$i]}\"" >> "$ftptransfere_file"
					fi
				fi
				echo "wait" >> "$ftptransfere_file"
			else 
				# directories
				if [[ $video_file_to_complete == "true" ]]; then
					echo "queue mirror --no-umask -p --parallel=$parallel -c -R \"${filepath[$i]}\" \"$ftpcomplete\"" >> "$ftptransfere_file"
				elif [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]]; then
					echo "queue mirror --no-umask -p --parallel=$parallel -c -R \"${filepath[$i]}\" \"$ftpincomplete\"" >> "$ftptransfere_file"
				elif [[ -z $ftpincomplete ]] || [[ $retry_option == "complete" ]]; then
					echo "queue mirror --no-umask -p --parallel=$parallel -c -R \"${filepath[$i]}\" \"$ftpcomplete\"" >> "$ftptransfere_file"
				fi
				echo "wait" >> "$ftptransfere_file"
			fi
		done
		# moving part, remotely
		if [[ -n $ftpincomplete ]] || [[ $retry_option == "incomplete" ]] && [[ $video_file_to_complete != "true" ]]; then
			for n in "${changed_name[@]}"; do #using several directories, like in mount
				if [[ "$n" == "$orig_name" ]]; then
					echo "queue mv \"$ftpincomplete$n/\" \"$ftpcomplete\"" >> "$ftptransfere_file"
				else
					echo "queue mv \"$ftpincomplete$n/\" \"$ftpcomplete$orig_name\"" >> "$ftptransfere_file"
				fi
				echo "wait" >> "$ftptransfere_file"
			done
		fi
		 # else assume $retry_option == "complete"
	elif [[ $transferetype == "fxp" ]]; then #NOT WORKING
		ftppath=${filepath##*/ftp/}
		ftppath=${ftppath%%/$orig_name/}
		echo "set ftp:use-fxp yes" >> "$ftptransfere_file"
		echo "set ftp:fxp-passive-source yes" >> "$ftptransfere_file"
		i=0
		for n in "${changed_name[@]}"; do
			if [[ ! -d ${transfer_path[$i]} ]]; then
				#perhaps not working?
				echo "mkdir \"$ftpincomplete${changed_name[$i]}\"" >> "$ftptransfere_file"
				echo "get ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"/$ftppath/${changed_name[$i]}/\" ftp://$ftpuser:$ftppass@$ftphost:$ftpport:\"$ftpincomplete\"" >> "$ftptransfere_file"
			else
				echo "queue mirror --no-umask -p -c --parallel=$parallel ftp://$ftpuser2:$ftppass2@$ftphost2:$ftpport2:\"/$ftppath/${changed_name[$i]}/\" ftp://$ftpuser:$ftppass@$ftphost:$ftpport:\"$ftpincomplete\"" >> "$ftptransfere_file"
			fi
			echo "wait" >> "$ftptransfere_file"
			echo "queue mv \"$ftpincomplete${changed_name[$i]}\" \"$ftpcomplete${orig_name[$i]}\"" >> "$ftptransfere_file"
			echo "wait" >> "$ftptransfere_file"
			let i++
		done
	else
		echo -e "\e[00;31mERROR: FTP setting not recognized\e[00m"
		cleanup die
	fi
	echo "quit" >> "$ftptransfere_file"
	}
	 #start transfering
	{
	if [[ $test_mode != "true" ]]; then
		ftp_transfer_process start
		#did lftp end properly
		while [[ $pid_transfer_status -eq 1 ]]; do
			quittime=$(( $ScriptStartTime + $retry_download_max*60*60 )) #hours
			if [[ $(date +%s) -gt $quittime ]]; then
				echo -e "\e[00;31mERROR: FTP transfer failed after max retries($retry_download_max hours)!\e[00m"
				echo "Program has ended"
				#remove processbar processes
				ftp_transfer_process "stop-process-bar"
				cleanup session
				cleanup end
				exit 0
			fi
			echo -e "\e[00;31mERROR: FTP transfer failed for some reason!\e[00m"
			echo "INFO: Keep trying until $(date --date=@$quittime '+%d/%m/%y-%a-%H:%M:%S')"
			# ok done, kill processbar
			kill -9 $pid_f_process &> /dev/null
			kill -9 $(sed -n '4p' "$lockfile") &> /dev/null
			echo -e "\e[00;31mTransfer terminated: $(date '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
			waittime=$(($retry_download*60))
			echo "INFO: Pausing session and trying again $retry_download"mins" later"
			sed "3s#.*#***************************	FTP INFO: DOWNLOAD POSTPONED! Trying again in "$retry_download"mins#" -i $logfile
			sleep $waittime
			# restart transfer
			ftp_transfer_process start
		done
		echo -e "\e[00;37mINFO: \e[00;32mTransfer ended: $(date --date=@$TransferEndTime '+%d/%m/%y-%a-%H:%M:%S')\e[00m"
		#remove processbar processes
		ftp_transfer_process "stop-process-bar"
	else
		echo -e "\e[00;31mTESTMODE: LFTP-transfer NOT STARTED\e[00m"
		echo "Would transfer:"
		i=0
		for n in "${changed_name[@]}"; do
			if [[ $video_file_to_complete == "true" ]]; then
				echo "	${filepath[$i]} --> to $ftpcomplete${orig_name[$i]}"
			else
				echo "	${filepath[$i]} --> $ftpincomplete and move that to $ftpcomplete${orig_name[$i]}"
			fi
			let i++
		done
	fi
	}
}

function ftp_processbar { #Showing how download is proceding
	if [[ "$processbar" == "true" ]]; then
		if [[ $test_mode != "true" ]]; then
			sleep 5 #wait for transfer to start
			loop="true"
			if [[ $transferetype == "downftp" ]]; then
				if [[ -z $1 ]] || [[ $retry_option == "incomplete" ]]; then
					local transfered_size="du -s \"$ftpincomplete$changed_name\" > \"$proccess_bar_file\""
				elif [[ $retry_option == "complete" ]]; then
					local transfered_size="du -s \"$ftpcomplete$changed_name\" > \"$proccess_bar_file\""
				fi
			elif [[ $transferetype == "upftp" ]]; then
				#Create configfile for lftp processbar
				cat "$ftplogin_file" >> "$ftptransfere_processbar"
				# ~ is /home/USER/
				if [[ -z $1 ]] || [[ $retry_option == "incomplete" ]]; then
					echo "du -s \"$ftpincomplete$changed_name\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
				elif [[ $retry_option == "complete" ]]; then
					echo "du -s \"$ftpcomplete$changed_name\" > ~/../..$proccess_bar_file" >> "$ftptransfere_processbar"
				fi
				echo "quit" >> "$ftptransfere_processbar"
			fi
			{ #run processbar loop
			while [[ "$loop" = "true" ]]; do
				if [[ ${#changed_name[@]} -gt 2 ]]; then
					echo "INFO: Progress not possible due to a lot of changing files"
					sed "5s#.*#***************************	Transfering: "$orig_name" - x% in x at x MB/s. ETA: x  #" -i $logfile
					break
				else
					if [[ $transferetype == "downftp" ]]; then
						sleep 5
						eval $transfered_size
					elif [[ $transferetype == "upftp" ]]; then
						sleep $sleeptime
						$lftp -f "$ftptransfere_processbar" &> /dev/null &
						pid_process=$!
						sed "4c $pid_process" -i $lockfile
						wait $pid_process
					fi
				fi
				if [[ $? -eq 0 ]]; then #require feedback from server!
					# checks tranfered size and converts til human readable sizes
					if [[ -a $proccess_bar_file ]]; then
						transfered=$(cat $proccess_bar_file | awk '{print $1}')
						diff=$(( $(date +%s) - $TransferStartTime ))
						timediff=$(printf '%02dh:%02dm:%02ds' "$(($diff/(60*60)))" "$((($diff/60)%60))" "$(($diff%60))")		
						# if not empty calculate values, if empty we know nothing
						if [[ "$transfered" -ge "1" ]] && [[ "$transfered" =~ ^[0-9]+$ ]]; then
								transfered=$(echo "scale=2; "$transfered" / (1024)" | bc)
								procentage=$(echo "scale=4; "$transfered" / "$size" * 100" | bc)
								procentage=$(echo $procentage | sed 's/\(.*\)../\1/')
								speed=$(echo "scale=2; ( $transfered ) / $diff" | bc)
								eta=$(echo "( $size - $transfered ) / $speed" | bc)
								etatime=$(printf '%02dh:%02dm:%02ds' "$(($eta/(60*60)))" "$((($eta/60)%60))" "$(($eta%60))")
							else
								speed="x"
								procentage="0"
								etatime="Unknown"
						fi
						#update file and output the current line
						sed "5s#.*#***************************	Transfering: "$orig_name" - $procentage% in $timediff at $speed MB/s. ETA: $etatime  #" -i $logfile
						echo -ne  "$procentage% is done in $timediff at $speed MB/s. ETA: $etatime\r"
					fi
				fi
			done
			}
			#new line
			echo -ne '\n'
		else
			echo -e "\e[00;31mTESTMODE: LFTP-processbar NOT STARTED\e[00m"
		fi
	fi
}

function logrotate {
	if [[ $test_mode != "true" ]]; then
			transferTime=$(( $TransferEndTime - $TransferStartTime ))
			transferTime2=$(printf '%02dh:%02dm:%02ds' "$(($transferTime/(60*60)))" "$((($transferTime/60)%60))" "$(($transferTime%60))")
			speed=$(echo "scale=2; $size / $transferTime" | bc)
			#Adds new info to 7th line, below everyhting statis
			sed "7i $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S') - $source - $orig_name, $size\MB, $transferTime2, $speed\MB/s" -i $logfile
			lognumber=$((7 + $lognumber ))
			#Add text to old file
			if [[ $logrotate == "true" ]]; then
				if [[ -n $(sed -n $lognumber,'$p' $logfile) ]]; then
					sed -n $lognumber,'$p' $logfile >> $oldlogfile
				fi
			fi
			#Remove text from old file
			if [ $lognumber -ne 0 ]; then
				sed $lognumber,'$d' -i $logfile
			fi
			totaldl=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' $logfile | cut -d' ' -f2)
			totaldl=${totaldl%MB}
			if [[ -z $totaldl ]]; then
				totaldl="0"
			fi
			totaldl=${totaldl%MB}
			totaldl=$(echo "$totaldl + $size" | bc)
			totalrls=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' $logfile | cut -d' ' -f4)
			totalrls=$(echo "$totalrls + 1" | bc)
			totaldltime=$(awk 'BEGIN{FS="|";OFS=" "}NR==2{print $1}' $logfile | cut -d' ' -f7)
			totaldltime_seconds=$(awk 'BEGIN{split("'$totaldltime'",a,":"); print a[1]*(60*60*24)+a[2]*(60*60)+a[3]*60+a[4];}')
			totaldltime=$(echo "$totaldltime_seconds + $transferTime" | bc)
			totaldltime=$(printf '%02dd:%02dh:%02dm:%02ds' "$(($totaldltime/(60*60*24)))" "$(($totaldltime/(60*60)%24))" "$((($totaldltime/60)%60))" "$(($totaldltime%60))")

			sed "1s#.*#***************************	FTPauto - $s_version#" -i $logfile
			sed "2s#.*#***************************	STATS: "$totaldl"MB in $totalrls transfers in $totaldltime#" -i $logfile
			sed "4s#.*#***************************	LASTDL: $(date) - "$orig_name" at "$speed"MB/s#" -i $logfile
			sed "5s#.*#***************************	#" -i $logfile
		else
			echo -e "\e[00;31mTESTMODE: LOGGING NOT STARTED\e[00m"
	fi
}

function loadConfig {
	# reload config
	source "$scriptdir/users/$user/config"

	#load paths to everything
	setup
	check_setup
}

function check_setup {
	# Add trailing slash if it is missing
	if [[ "$ftpincomplete" != */ ]]; then
		ftpincomplete="$ftpincomplete/"
	fi
	if [[ "$ftpcomplete" != */ ]]; then
		ftpcomplete="$ftpcomplete/"
	fi
}

function lockfile {
	case "$1" in
		running )
			true
			;;
		* ) # upon start no option is available, hence create lockfile
			echo "INFO: Writing lockfile: $lockfile"
			if [[ -f "$lockfile" ]] && [[ $force != "true" ]]; then
				#The file exists, find PID, transfere, confirm it still is running
				mypid_script=$(sed -n 1p "$lockfile")
				mypid=$(sed -n 2p "$lockfile")
				alreadyinprogres=$(sed -n 3p "$lockfile")
				kill -0 $mypid_script
				if [[ $? -eq 1 ]]; then
					#Process is not running, continue
					echo "INFO: No lockfile detected"
					rm "$lockfile"
				else
					echo -e "\e[00;31mINFO: The user $user is running something\e[00m"
					echo "       The script running is: $mypid_script"
					echo "       The transfere is: $alreadyinprogres"
					echo "       If that is wrong remove $lockfile"
					echo "       Wait for it to end, or kill it: kill -9 $mypid_script"
					queue add end
				fi
			fi
			#allocate pids
			echo >> "$lockfile"
			echo >> "$lockfile"
			echo >> "$lockfile"
			echo >> "$lockfile"
			sed "1c $BASHPID" -i "$lockfile"
			echo "INFO: Process id: $BASHPID"
		;;
	esac
}

function load_help {
	if [[ -e "$scriptdir/dependencies/help.sh" ]]; then
		source "$scriptdir/dependencies/help.sh"
	else
		echo -e "\e[00;31mError: /dependencies/help.sh is\n needed in order for this program to work\e[00m";
		exit 1
	fi
}

function main {
#setting paths
filepath="$1"
orig_path="$filepath"
orig_name=$(basename "$filepath")
# Use change_name in script as it might change later on (largefile)
changed_name="$orig_name"
tempdir="$scriptdir/run/$username-temp/$orig_name/"
ScriptStartTime=$(date +%s)
echo "INFO: Process starttime: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
echo "INFO: Preparing transfere: $filepath"
echo "INFO: Lunched from: $source"

#add to queue file, to get ID initialized
queue add

echo "INFO: Simultaneous transferes: $parallel"

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
source "$scriptdir/dependencies/ftp_login.sh" && ftp_login

#confirm server is online
if [[ $confirm_online == "true" ]]; then
	source "$scriptdir/dependencies/ftp_online_test.sh" && online_test
fi


#Check if enough free space on ftp
if [[ "$ftpsizemanagement" == "true" ]]; then
	if [[ $transferetype == "upftp" ]]; then
		source "$scriptdir/dependencies/ftp_size_management.sh" && ftp_sizemanagement check
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
			source "$scriptdir/dependencies/largefile.sh" && largefile "$filepath" "exclude_array[@]"
		elif [[ $transferetype == "downftp" ]]; then
			echo -e "\e[00;33mERROR: split_files is not supported in mode=$transferetype. Continuing without ...\e[00m"
		fi
	else
		echo -e "\e[00;33mERROR: split_files is not supported as rar or cksfv is missing. Continuing without ...\e[00m"
	fi
# Try to only send videofile
elif [[ "$send_option" == "video" ]]; then
	if [[ -n $(builtin type -p rarfs) ]]; then
		if [[ $transferetype == "upftp" ]]; then
			source "$scriptdir/plugins/videofile.sh" && videoFile
		elif [[ $transferetype == "downftp" ]]; then
			echo -e "\e[00;33mERROR: video_file_only is not supported in mode=$transferetype. Continuing without ...\e[00m"
		fi
	else
		echo -e "\e[00;33mERROR: split_files is not supported as rarfs is missing. Continuing without ...\e[00m"
	fi
fi

# Try to sort files
if [[ "$sort" == "true" ]]; then
	source "$scriptdir/dependencies/sorting.sh" && sortFiles "$sortto"
fi

# Delay transfer if needed
delay

# Transfer files
ftp_transfere

# Checking for remaining space
if [[ "$ftpsizemanagement" == "true" ]]; then
	ftp_sizemanagement info # already loaded previously
fi

# Update logfile
logrotate

# Clean up current session
cleanup session

#send push notification
if [[ -n $push_user ]]; then
	if [[ $test_mode != "true" ]]; then
		source "$scriptdir/plugins/pushover.sh" "NEW STUFF: $orig_name, "$size"MB, in $transferTime2, "$speed"MB/s"
	else
		echo -e "\e[00;31mTESTMODE: Would send notification \"NEW STUFF: $orig_name, "$size"MB, in $transferTime2, "$speed"MB/s\" to token=$push_token and user=$push_user \e[00m"
	fi
fi
echo

#Execute external command
if [[ -n $exec_post ]]; then
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
echo -e "\e[00;37mINFO: \e[00;32mFinished\e[00m"
echo "                       Name: $orig_name"
echo "                       Size: $size MB"
echo "                      Speed: $speed MB/s"
echo "              Transfer time: $transferTime2"
echo "                 Start time: $(date --date=@$ScriptStartTime '+%d/%m/%y-%a-%H:%M:%S')"
echo "                   End time: $(date --date=@$ScriptEndTime '+%d/%m/%y-%a-%H:%M:%S')"
echo "                 Total time: $(printf '%02dh:%02dm:%02ds' "$(($TotalTransferTime/(60*60)))" "$((($TotalTransferTime/60)%60))" "$(($TotalTransferTime%60))")"

# Remove finished one
queue remove
# Run queue
queue run
}

function start_main {
#Look for which options has been used
if (($# < 1 )); then echo; echo -e "\e[00;31mERROR: No option specified\e[00m"; echo "See --help for more information"; echo ""; exit 0; fi
while :
do
	case "$1" in
		--path=* ) filepath="${1#--path=}"; shift;;
		--user=* ) user="${1#--user=}"; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; shift;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; shift;;
		--delay=* ) delay="${1#--delay=}"; shift;;
		--force | -f ) force=true; shift;;
		--source=* ) source="${1#--source=}"; shift;;
		--sortto=* ) sortto="${1#--sortto=}"; shift;;
		--example ) load_help; show_example; exit 0;;
		--test ) test_mode="true"; echo "INFO: Running in TESTMODE, no changes are made!"; shift;;
		* ) break ;;
		--) shift; break;;
	esac
done

# main program starts here

# confirm filepath
if [[ -z "$filepath" ]]; then
	# if --path is not used, try and run queue
	queue run
elif [[ -z $(find "$filepath" -type d 2>/dev/null) ]] && [[ -z $(find "$filepath" -type f 2>/dev/null) ]] || [[ -z $(find "$filepath" -type f 2>/dev/null) ]]; then
	# path with files or file not found
	if [[ "$transferetype" == "downftp" ]]; then
		# server <-- client, assume path is OK
		lockfile "$lockfileoption"
		true
	elif [[ "$transferetype" == "upftp" ]]; then		
		# server --> client
		echo -e "\e[00;31mERROR: Option --path is required with existing path (with file(s)), or file does not exists:\n $filepath\n This cannot be transfered!\e[00m"
		echo
		exit 1
	else
		echo "INFO: Transfertype \"$transferetype\" not recognized. Have a look on your config"
		echo
		exit 1				
	fi
fi
# Create lockfile
lockfile "$lockfileoption"

echo "INFO: Transfertype: $transferetype"

#Load dependencies
source "$scriptdir/dependencies/setup.sh"

#Check wether we have an external config, user config or no config at all
loadConfig

# OK nothing running and --path is real, lets continue
# fix spaces: "/This\ is\ a\ path"
# Note: The use of normal backslashes is NOT supported
filepath="$(echo "$filepath" | sed 's/\\./ /g')"

#start program
main "$filepath"
}
