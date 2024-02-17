#!/bin/bash
### code below
function setup {
	# add local paths here
	PATH=$HOME/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
	# if programs has been installed in custom locations the executeable can be set here
	lftp=$(which lftp)
	rar2fs=$(which rar2fs)
	# paths for internal files
	login_file1="$scriptdir/run/$username.login1"
	login_file2="$scriptdir/run/$username.login2"
	lftpdebug="$scriptdir/run/$username.lftpdebug"
	lftptransfersize="$scriptdir/run/$username.transfersize"
	lftptransfersize2="$scriptdir/run/$username.lftptransfersize2"
	lockfile="$scriptdir/run/$username.lck"
	log_control="$scriptdir/run/$username.controllog"
	logfile="$scriptdir/users/$username/log"
	maindebugfile="$scriptdir/run/$username.main.debug"
	oldlogfile="$scriptdir/users/$username/log.old"
	proccess_bar_file="$scriptdir/run/$username.transfered.info"
	queue_file="$scriptdir/run/$username.queue"
	server_alive_file="$scriptdir/run/$username.serveralive"
	server_check_file="$scriptdir/run/$username.servercheck"
	server_check_testfile="$scriptdir/run/$username.servertestfile"
	server_content="$scriptdir/run/$username.servercontent"
	server_freespace_file="$scriptdir/run/$username.serverfreespace"
	server_list_file="$scriptdir/run/$username.lftplist"
	server_size_file="$scriptdir/run/$username.serversize.info"
	transfere_file="$scriptdir/run/$username.transfere"
	transfere_processbar="$scriptdir/run/$username.processbar"
	transfersize="$scriptdir/run/$username.transfersize"
	transfersize2="$scriptdir/run/$username.transfersize2"
}

# Function to get the size of a file or directory
function get_size {
	# Called with $filepath
	local dir n count i exp path t_size

	dir="$1"

	if [[ "$transferetype" == downftp || "$transferetype" == fxp ]]; then
		# Client-side transfer
		loadDependency DFtpLogin && ftp_login 1
		cat "$login_file1" > "$lftptransfersize" >> "$lftptransfersize"
		echo "du -bs \"$dir\" > ~/../..$transfersize" >> "$lftptransfersize"
		echo "ls -lR \"$dir\" > ~/../..$transfersize2" >> "$lftptransfersize"
		echo "exit" >> "$lftptransfersize"
		"$lftp" -f "$lftptransfersize" &> /dev/null

		# Determine if it's a file or directory
		local count=0
		while read -r line; do
			let ++count
		done <"$transfersize2"
		if [[ $count -gt 0 ]]; then
			echo "INFO: Transferring a directory"
			transfer_type="directory"
		else
			echo "INFO: Transferring a file"
			transfer_type="file"
		fi

		if [[ "${#exclude_array[@]}" -gt 0 && -n "${exclude_array[@]}" ]]; then
			# Size lookup if expression is used
			# Prepare regex
			local exp=() n=0
			for i in "${exclude_array[@]}"; do
				(( n++ ))
				[[ $n -lt ${#exclude_array[@]} && $n -ge 1 ]] && exp+="|"
				exp+="$i"
			done

			# Loop through result from lftp
			size=0
			while read -r line; do
				if [[ -n $(echo "$line" | egrep '('$exp')') ]]; then
					# Ignore files in regex
					continue
				fi
				if [[ -n $(echo "$line" | egrep '\/(.*):') ]]; then
					# Catch subdirectories path to add to the files
					path="$line"
					path=${path%:}
					path="$path/"
					continue
				fi
				if [[ -n "$line" && $(echo "$line" | awk '{print $5}') -gt 0 ]]; then
					# Make sure line contains something
					# Remove entries without size
					if [[ $(echo "$line" | awk '{print $2}') == "2" ]]; then
						# Catch directories
						t_size=$(echo "$line" | awk '{print $5}')
						full_path="$path$(echo "$line" | awk '{print $9}')/"
					fi
					t_size=$(echo "$line" | awk '{print $5}')
					size=$(echo "$size + $t_size" | bc)
				fi
			done < "$transfersize2"
		else
			size=$(awk '{print $1}' < "$transfersize")
		fi

		directorysize="$size"
		size=$(echo "scale=2; $size / (1024 * 1024)" | bc)
		if [[ ${#exclude_array[@]} -eq 0 ]]; then
			echo "INFO: Size to transfer: ${size}MB"
		else
			echo "INFO: Size to transfer (regex used): ${size}MB"
		fi

		cleanup session
	elif [[ "$transferetype" == upftp || "$transferetype" == upsftp ]]; then
		# Look up directory or file size locally
		directorysize=$(du -bsL "$dir" | awk '{print $1}')
		size=$(echo "scale=2; $directorysize / (1024 * 1024)" | bc)
		echo "INFO: Size to transfer: ${size}MB"

		# Exclude files matching passed regex
		if [[ "${#exclude_array[@]}" -gt 0 && -n "${exclude_array[@]}" ]]; then
			exclude_expression=()
			n=1
			for i in "${exclude_array[@]}"; do
				exclude_expression+=("-iname *$i*")
				# Add -or if not finished
				if [[ "$n" -lt ${#exclude_array[@]} ]]; then
					exclude_expression+=("-or")
				fi
				(( n++ ))
			done
			exclude_expression="${exclude_expression[@]}"
			directorysize=$(find -L "$dir" \! \( $exclude_expression \) -type f -printf '%s\n' | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}') # in bytes
			size=$(echo "scale=2; $directorysize / (1024 * 1024)" | bc)
			echo "INFO: Updated size to transfer (regex used): ${size}MB"
		fi
	fi
}

# Function to remove files from an array
function removeClean {
	local array
	array=("$@")
	# Iterate through array and remove files
	for i in "${array[@]}"; do
		rm -f "$i"
	done
}

# Function to perform cleanup operations
function cleanup {
	local array
	case "$1" in
	"die" ) # Used when script stops on user input
		echo -e "\n*** Ouch! Exiting ***\n"
		stty sane
		if [[ "$safelock" != "true" ]]; then
			# Stop processes, cleanup session, remove lockfile/end session
			cleanup stop-safe
			cleanup session
			cleanup end
			sed "5s#.*#***************************	Transfer: Aborted #" -i "$logfile"
		fi
		exit 1;;
	"session" ) # Use to end session of transfer
		if [[ $test_mode == "true" ]]; then
			read -sn 1 -p "Press ANY button to continue cleanup..."
		fi
		if [[ $mount_in_use == "true" ]]; then
			mountsystem umount
			unset mount_in_use
		fi
		# Define array of files to remove
		array=( "$login_file1" "$login_file2" "$lftpdebug" "$lftptransfersize" "$lftptransfersize2" "$lockfile" "$log_control" "$maindebugfile" "$oldlogfile" "$proccess_bar_file" "$server_alive_file" "$server_check_file" "$server_check_testfile" "$server_content" "$server_freespace_file" "$server_list_file" "$server_size_file" "$transfere_file" "$transfere_processbar" "$transfersize" "$transfersize2" )
		# Call removeClean function to remove files
		removeClean "${array[@]}"
		# Remove tempdirs
		if [[ -d "$scriptdir/run/$username-temp" ]]; then
			rm -r "$scriptdir/run/$username-temp"
		fi
		echo -e "INFO: Session cleanup done"
	;;
	"end" ) # Use to end script
		removeClean "$lockfile"
		sed "5s#.*#***************************	#" -i "$logfile"
		echo -e "\e[00;32mExiting successfully...\e[00m\n"
	;;
	"stop-safe" ) # Use to terminate all pids except main process
		for i in {2..4}; do
			if [[ -n "$(sed -n "${i}p" "$lockfile")" ]]; then
				kill "$(sed -n "${i}p" "$lockfile")" &> /dev/null
				wait "$(sed -n "$i p" "$lockfile")" 2>/dev/null
			fi
		done
	;;
	"stop" ) # Use to terminate all pids found in the lockfile
		for i in {1..4}; do
			if [[ -n "$(sed -n "${i}p" "$lockfile")" ]]; then
				kill "$(sed -n "${i}p" "$lockfile")" &> /dev/null
				wait "$(sed -n "$i p" "$lockfile")" 2>/dev/null
			fi
		done
	;;
esac
}
