#!/bin/bash
### code below
function setup {
	# add local paths here
	PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# if programs has been installed in custom locations the executeable can be set here
	lftp=$(which lftp)
	rar2fs=$(which rar2fs)
	# paths for internal files
	queue_file="$scriptdir/run/$username.queue"
	lockfile="$scriptdir/run/$username.lck"
	logfile="$scriptdir/users/$username/log"
	oldlogfile="$scriptdir/users/$username/log.old"
	ftptransfere_file="$scriptdir/run/$username.ftptransfere"
	ftptransfere_processbar="$scriptdir/run/$username.ftpprocessbar"
	ftplogin_file1="$scriptdir/run/$username.ftplogin1"
	ftplogin_file2="$scriptdir/run/$username.ftplogin2"
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
	transfersize2="$scriptdir/run/$username.transfersize2"
	lftptransfersize2="$scriptdir/run/$username.lftptransfersize2"
	ftplist_file="$scriptdir/run/$username.lftplist"
	ftp_content="$scriptdir/run/$username.ftpcontent"
}

function get_size {
	# called with $filepath
	local dir n count i exp path t_size directorysize sizeBytes
	dir="$1"
	if [[ "$transferetype" == downftp ]] || [[ "$transferetype" == fxp ]]; then
		#client
		loadDependency DFtpLogin && ftp_login 1
		cat "$ftplogin_file1" > "$lftptransfersize" >> "$lftptransfersize"
		echo "du -bs \"$dir\" > ~/../..$transfersize" >> "$lftptransfersize"
		echo "ls -lR \"$dir\" > ~/../..$transfersize2" >> "$lftptransfersize"
		echo "exit" >> "$lftptransfersize"
		"$lftp" -f "$lftptransfersize" &> /dev/null
		# figure out if it is a file or directory
		local count=0
		while read line; do
			let ++count
		done <"$transfersize2"
		if [[ $count -gt 0 ]]; then
			echo "INFO: Transfering a directory"
			transfer_type="directory"
		else
			echo "INFO: Transfering a file"
			transfer_type="file"
		fi
		if [[ -n "${#exclude_array[@]}" ]]; then
			# size lookup if expression is used
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
			size=0
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
				if [[ -n "$line" ]]; then
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
					size=$(echo $size + $t_size | bc)
				fi
			done < "$transfersize2"
		else
			size=$(cat "$transfersize" | awk '{print $1}')
		fi
		size=$(echo "scale=2; "$size" / (1024*1024)" | bc)
		if [[ ${#exclude_array[@]} -eq 0 ]]; then
			echo "INFO: Size to transfere: ${size}MB"
		else
			echo "INFO: Size to transfere(regex used): ${size}MB"
		fi
		cleanup session
	elif [[ "$transferetype" == upftp ]]; then
		# look up directory or file size locally
		directorysize=$(du -bsL "$dir" | awk '{print $1}')
		size=$(echo "scale=2; "$directorysize" / (1024*1024)" | bc)
		echo "INFO: Size to transfere: ${size}MB"
		# exclude files matching passed regex
		if [[ -n "${#exclude_array[@]}" ]]; then
			exclude_expression=()
			n="1"
			for i in "${exclude_array[@]}"; do
				exclude_expression+=("-iname *$i*")
				#add -or if not finished
				if [[ "$n" -lt "${#exclude_array[@]}" ]]; then
					exclude_expression+=("-or")
				fi
				let n++
			done
			exclude_expression="${exclude_expression[@]}"
			sizeBytes=$(find -L "$dir" \! \( $exclude_expression \) -type f -printf '%s\n' | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}') # in bytes
			size=$(echo "scale=2; $sizeBytes / (1024*1024)" | bc)
			echo "INFO: Updated size to transfere(regex used): ${size}MB"
		fi
	fi
}

function removeClean {
	local array
	array=("$@")
	# removes passed files
	for i in "${array[@]}"; do
		rm -f "$i"
	done
}

function cleanup {
	local array
	case "$1" in
	"die" ) #used when script stops on user input
		echo -e "\n*** Ouch! Exiting ***\n"
		stty sane
		if [[ "$safelock" != "true" ]]; then
			# 1) stop processes, 2) cleanup session, 3) remove lockfile/end session
			cleanup stop
			cleanup session
			cleanup end
			sed "5s#.*#***************************	Transfer: Aborted #" -i $logfile
		fi
		exit 1;;
	"session" ) #use to end session of transfer
		if [[ $test_mode == "true" ]]; then
			read -sn 1 -p "Press ANY button to continue cleanup..."
		fi
		if [[ $mount_in_use == "true" ]]; then
			mountsystem umount
			unset mount_in_use
		fi
		# removal of all files creates
		array=( "$ftplogin_file1" "$ftplogin_file2" "$ftptransfere_file" "$ftp_size_file" "$ftpfreespace_file" "$lftptransfersize" "$lftptransfersize2" "$transfersize" "$transfersize2" "$proccess_bar_file" "$ftpalive_file" "$ftpcheck_file" "$ftpcheck_testfile" "$ftptransfere_processbar" )
		removeClean "${array[@]}"
		# removal of tempdirs
		if [[ -d "$scriptdir/run/$username-temp" ]]; then rm -r "$scriptdir/run/$username-temp"; fi;
		echo -e "INFO: Cleanup done"
	;;
	"end" ) #use to end script
		removeClean "( "$lockfile" )"
		sed "5s#.*#***************************	#" -i $logfile
		echo -e "\e[00;32mExiting successfully...\e[00m\n"
	;;
	"stop" ) #use to terminate all pids found in the lockfile
		for i in {1..4}; do
			if [[ -n "$(sed -n "${i}p" $lockfile)" ]]; then kill $(sed -n "${i}p" $lockfile) &> /dev/null; wait $(sed -n "$i p" $lockfile) 2>/dev/null;  fi
		done
	;;
esac
}
