#!/bin/bash
function ftp_list {
	echo "INFO: Looking up content on ftp..."
	if [[ -z $dir ]]; then
		dir="/"
	fi
	while true; do
		get_content "$dir"
		read -p "Enter number to expand directory or download by also adding a \"d\", fx. 1d ? (x to exit) "
		# make sure number is inserted
		while ! [[ "$REPLY" =~ [0-9] ]] && [[ $REPLY != "x" ]]; do
			read -p " Enter number to expand directory or download by also adding a \"d\", fx. 1d ? (x to exit) "
		done			
		number=$REPLY
		if [[ "$number" == "x" ]]; then
			break
		elif [[ "$number" == "0" ]]; then
			# go to top path
			dir="/"
			continue
		elif [[ "$number" == "1" ]]; then
			# remove last path component
			dir=$(dirname "$dir")
			continue
		elif [[ "$number" =~ ^[0-9]+d ]]; then
			# extract number
			number=${number%d}
			# make download
			path="$dir$(echo ${array_list[$number]} | awk '{print $9}')"
			download_argument+=("--user=$username")
			download_argument+=("--path=/$path")
			download_argument+=("--source=Manually")
			# change option
			option[0]="download"
			read -p " Do you want download it now(y/n)? "
			if [[ $REPLY == "y" ]]; then
				option[1]="start"
				read -p " Do you want it to run in the background. If yes, then you can continue to add items(y/n)? "
				if [[ $REPLY == "y" ]]; then
					background=true
					main &> /dev/null &
				else
					main
				fi
			else
				# todo. Bad fix to avoid starting download
				echo " Adding $path to queue"
				continue_queue="false"
				option[1]="queue"
				main &> /dev/null &
			fi
			# unset the added path and stay in current directory.
			unset path download_argument
		else
			# do normal listing
			if [[ "$dir$(echo ${array_list[$number]} | awk '{print $9}')" != */ ]]; then
				# not a directory
				echo -e "\e[00;31m Cannot expand file: $(echo ${array_list[$number]} | awk '{print $9}')\e[00m"
				continue
			fi
			dir="$dir$(echo ${array_list[$number]} | awk '{print $9}')"
			continue
		fi
	done
	
	# Ask to start download if something has been added
	if [[ -e "$queue_file" ]]; then
		read -p " Do you want to start the download (y/n)? "
		if [[ $REPLY == "y" ]]; then
			background=true
			main
		fi
	fi
}
function get_content {
	# remove old file first
	rm -f "$ftplist_file"
	source "$scriptdir/dependencies/ftp_login.sh" && ftp_login # we need to generate a new each time as download removes it
	cat "$ftplogin_file" >> "$ftplist_file"
	echo "ls -aFl "$dir" > ~/../..$ftp_content" >> "$ftplist_file"
	echo "quit" >> "$ftplist_file"
	$lftp -f "$ftplist_file" &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo ""
		echo -e "\e[00;32mINFO: Listing content(s):\e[00m"
		echo " Current path: $dir"
		old_dir="$dir"
		array_list=()
		readarray array_list < "$ftp_content"
		i=0
		# find lenght of array and add zero
		for value in "${array_list[@]}"; do
			printf "%-8s\n" "$i : $(echo $value | awk '{print $9}')"
			let i++
		done | column -c 1 -t
	fi
	# cleanup
	rm -f "$ftplist_file"
	rm -f "$ftp_content"
}