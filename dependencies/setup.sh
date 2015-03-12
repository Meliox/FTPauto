#!/bin/bash
### code below
function setup {
	#
	PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# programs
	lftp=$(which lftp)
	rarfs=$(which rar2fs)
	# paths
	queue_file="$scriptdir/run/$username.queue"
	lockfile="$scriptdir/run/$username.lck"
	logfile="$scriptdir/users/$username/log"
	oldlogfile="$scriptdir/users/$username/log.old"
	ftptransfere_file="$scriptdir/run/$username.ftptransfere"
	ftptransfere_processbar="$scriptdir/run/$username.ftpprocessbar"
	ftplogin_file="$scriptdir/run/$username.ftplogin"
	ftpfreespace_file="$scriptdir/run/$username.ftpfreespace"
	ftpalive_file="$scriptdir/run/$username.ftpalive"
	ftpcheck_testfile="$scriptdir/run/$username.testfile"
	ftpcheck_file="$scriptdir/run/$username.ftpcheck"
	proccess_bar_file="$scriptdir/run/$username.transfered.info"
	ftp_size_file="$scriptdir/run/$username.ftpsize.info"
	log_control="$scriptdir/run/$username.controllog"
	ftpmaindebugfile="$scriptdir/run/$username.ftpmain.debug"
	lftpdebug="$scriptdir/run/$username.lftpdebug"
	lftptransfersize="$scriptdir/run/$username.ftptransfersize"
	transfersize="$scriptdir/run/$username.transfersize"
	lftptransfersize2="$scriptdir/run/$username.lftptransfersize2"
	ftplist_file="$scriptdir/run/$username.lftplist"
	ftp_content="$scriptdir/run/$username.ftpcontent"
}

function get_size {
	#called with $filepath
	local dir="$1"
	if [[ "$transferetype" == "downftp" ]]; then
		#client
		# size lookup without expression
		source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
		cat "$ftplogin_file" > "$lftptransfersize"
		echo "du -bs \"$dir\" > ~/../..$transfersize" >> "$lftptransfersize"
		echo "ls -l \"$dir\" > ~/../..$transfersize" >> "$lftptransfersize2"
		echo "exit" >> "$lftptransfersize"
		"$lftp" -f "$lftptransfersize" &> /dev/null
		# figure out if it is a file or directory
		local count=0
		while read line; do
			let ++count
		done <"$lftptransfersize2"
		if [[ $count -gt 0 ]]; then
			echo "INFO: Transfering a directory"
			transfer_type="directory"
		else
			echo "INFO: Transfering a file"
			transfer_type="file"
		fi
		size=$(cat "$transfersize" | awk '{print $1}')
		size=$(echo "scale=2; "$size" / (1024*1024)" | bc)
		echo "INFO: Size to transfere: "$size"MB"
		cleanup session
		if [[ -n "${exclude_array[@]}" ]]; then
			# size lookup if expression is used
			cat "$ftplogin_file" > "$lftptransfersize"
			echo "ls -lR \"$dir\" > ~/../..$transfersize" >> "$lftptransfersize"
			echo "exit" >> "$lftptransfersize"
			"$lftp" -f "$lftptransfersize" &> /dev/null
			# prepare regex
			exp=()
			n="0"
			for i in "${exclude_array[@]}"; do
				if [[ $n -lt "${#exclude_array[@]}" ]] && [[ $n -ge 1 ]]; then
						exp+="|"
				fi
				exp+="$i"
				let n++
			done
			# loop through result from lftp
			while read line; do
				if [[ -n $(echo "$line" | egrep '('$exp')') ]]; then
						# ignore files in regex
						continue
				fi
				if [[ -n $(echo "$line" | egrep '\/(.*):') ]]; then
					# catch subdirectories path to add to the files
					path="$line"
					path=${path%:}
					path="$path/"
					continue
				fi
				if [[ -n $(echo "$line") ]]; then
					# make sure line contains something
					if [[ "$(echo "$line" | awk {'print $5'})" -gt "0" ]]; then
						# remove entries without size
						if [[ "$(echo "$line" | awk {'print $2'})" == "2" ]]; then
							# catch directories
							t_size=$(echo "$line" | awk {'print $5'})
							full_path="$path$(echo "$line" | awk {'print $9'})/"
						fi
					fi
					t_size=$(echo "$line" | awk {'print $5'})
					#full_path="$path$(echo "$line" | awk {'print $9'})"
					size=$(( $size + $t_size ))
				fi
			done < "$transfersize"
		fi
		cleanup session
	elif [[ "$transferetype" == "upftp" ]]; then
		#server
		directorysize=$(du -bs "$dir" | awk '{print $1}')
		size=$(echo "scale=2; "$directorysize" / (1024*1024)" | bc)	
		echo "INFO: Size to transfere: "$size"MB"
		if [[ -n "${exclude_array[@]}" ]]; then
			exclude_expression=()
			local n="1"
			for i in "${exclude_array[@]}"; do
				exclude_expression+=("-iname *$i*")
				#add -or if not finished
				if [[ "$n" -eq "${#exclude_expression[@]}" ]]; then
					exclude_expression+=("-or")
				fi
				let n++
			done
			exclude_expression=${exclude_expression[@]}
			size=$(find "$dir" \! \( $exclude_expression \) -type f -printf '%s\n' | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}')
			size=$(echo "scale=2; "$size" / (1024*1024)" | bc)
			echo "INFO: Updated size to transfere(filter used): "$size"MB"
		fi
	fi
}

function cleanup {
	case "$1" in
	"die" ) #used when script stops on user input
		echo "*** Ouch! Exiting ***"
		# remove pids and lockfile
		if [[ -n "$pid_transfer" ]]; then kill -9 $pid_transfer &> /dev/null; fi
		if [[ -n "$pid_f_process" ]]; then kill -9 $pid_f_process &> /dev/null; fi
		if [[ -f "$lockfile" ]] && [[ -n $(sed -n '4p' $lockfile) ]]; then kill -9 $(sed -n '4p' $lockfile) &> /dev/null; fi
		if [[ -f "$queue_file" ]]; then rm "$queue_file"; fi;
		if [[ -f "$lockfile" ]]; then rm "$lockfile"; fi;
		#remove all files created
		cleanup session
		sed "5s#.*#*************************** Transfer: Aborted #" -i $logfile
	        exit 1;;
	"session" ) #use to end transfer
		if [[ $test_mode == "true" ]]; then
			read -sn 1 -p "Press ANY buttom to continue cleanup..."
		fi
		if [[ $mount_in_use == "true" ]]; then
			mountsystem umount
			unset mount_in_use tempmountset
		fi
		# removal of all files creates
		if [[ -f "$ftplogin_file" ]]; then rm "$ftplogin_file"; fi
		if [[ -d "$tempdir" ]]; then rm -r "$tempdir"; fi;
		if [[ -f "$ftptransfere_file" ]]; then rm "$ftptransfere_file"; fi
		if [[ -f "$ftp_size_file" ]]; then rm "$ftp_size_file"; fi
		if [[ -f "$ftpfreespace_file" ]]; then rm "$ftpfreespace_file"; fi
		if [[ -f "$lftptransfersize" ]]; then rm "$lftptransfersize"; fi
		if [[ -f "$lftptransfersize2" ]]; then rm "$lftptransfersize2"; fi
		if [[ -f "$transfersize" ]]; then rm "$transfersize"; fi
		if [[ -f "$proccess_bar_file" ]]; then rm "$proccess_bar_file"; fi
		if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi
		if [[ -f "$ftpcheck_file" ]]; then rm "$ftpcheck_file"; fi
		if [[ -f "$ftpcheck_testfile" ]]; then rm "$ftpcheck_testfile"; fi
		if [[ -f "$ftptransfere_processbar" ]]; then rm "$ftptransfere_processbar"; fi
		echo "INFO: Cleanup done"
	;;
	"end" ) #use to end script
		if [[ -f "$lockfile" ]]; then rm "$lockfile"; fi;
		sed "5s#.*#***************************	#" -i $logfile
		echo -e "\e[00;32mExiting succesfully...\e[00m"
		echo ""
	;;
	"stop" ) #use to terminate all pids used
		if [[ -n $(sed -n '1p' $lockfile) ]]; then kill -9 $(sed -n '1p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '2p' $lockfile) ]]; then kill -9 $(sed -n '2p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '3p' $lockfile) ]]; then kill -9 $(sed -n '3p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '4p' $lockfile) ]]; then kill -9 $(sed -n '4p' $lockfile) &> /dev/null; fi
	;;
esac
}
