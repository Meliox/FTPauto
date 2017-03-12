#!/bin/bash
### code below
function setup {
	#
	PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# programs
	lftp=$(which lftp)
	rarfs=$(which rarfs)
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
		loadDependency DFtpLogin && ftp_login
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
			local exp=() n="0"
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
				if [[ "$n" -lt "${#exclude_array[@]}" ]]; then
					exclude_expression+=("-or")
				fi
				let n++
			done
			exclude_expression="${exclude_expression[@]}"
			sizeBytes=$(find "$dir" \! \( $exclude_expression \) -type f -printf '%s\n' | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}') # in bytes
			size=$(echo "scale=2; "$sizeBytes" / (1024*1024)" | bc)
			echo "INFO: Updated size to transfere(filter used): "$size"MB"
		fi
	fi
}

function removeClean {
	local array=("$@")
	# removes passed files
	for i in "${array[@]}"; do
		rm -f "$i"
	done
}

function cleanup {
	case "$1" in
	"die" ) #used when script stops on user input
		echo -e "\n*** Ouch! Exiting ***\n"
		stty sane
		if [[ "$safelock" != "true" ]]; then 
			# remove pids and lockfile
			if [[ -n "$pid_transfer" ]]; then kill -9 $pid_transfer &> /dev/null; fi
			if [[ -n "$pid_f_process" ]]; then kill -9 $pid_f_process &> /dev/null; fi
			if [[ -f "$lockfile" ]] && [[ -n $(sed -n '4p' $lockfile) ]]; then kill -9 $(sed -n '4p' $lockfile) &> /dev/null; fi
			local array=( "$lockfile" )
			removeClean "${array[@]}"
			#remove all files created
			cleanup session
			sed "5s#.*#***************************	Transfer: Aborted #" -i $logfile
		fi
		exit 1;;
	"session" ) #use to end transfer
		if [[ $test_mode == "true" ]]; then
			read -sn 1 -p "Press ANY button to continue cleanup..."
		fi
		if [[ $mount_in_use == "true" ]]; then
			mountsystem umount
			if [[ $? -eq 1 ]]; then
				echo -e "\e[00;33m\nINFO: Umounting failed. Retrying in 10s... \e[00m"
				sleep 10
				mountsystem umount
				if [[ $? -eq 1 ]]; then
					echo -e "\e[00;33m\nINFO: Umounting failed. Could not umount files (try manually fusermount -u): "${tempmountset[@]}" \e[00m"
				fi
			fi
			unset mount_in_use tempmountset
		fi
		# removal of all files creates
		local array=( "$ftplogin_file" "$ftptransfere_file" "$ftp_size_file" "$ftpfreespace_file" "$lftptransfersize" "$lftptransfersize2" "$transfersize" "$proccess_bar_file" "$ftpalive_file" "$ftpcheck_file" "$ftpcheck_testfile" "$ftptransfere_processbar" )
		removeClean "${array[@]}"
		# removal tempdir
		if [[ -d "$tempdir" ]]; then rm -r "$tempdir"; fi;
		echo -e "INFO: Cleanup done\n"
	;;
	"end" ) #use to end script
		local array=( "$lockfile" )
		removeClean "${array[@]}"
		sed "5s#.*#***************************	#" -i $logfile
		echo -e "\e[00;32mExiting successfully...\e[00m\n"
	;;
	"stop" ) #use to terminate all pids found in the lockfile
		for i in {1..4}; do
			if [[ -n "$(sed -n "$i p" $lockfile)" ]]; then kill -9 $(sed -n "$i p" $lockfile) &> /dev/null;	fi
		done
	;;
esac
}
