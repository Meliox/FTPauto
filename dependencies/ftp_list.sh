#!/bin/bash
function ftp_list {
	echo "INFO: Looking up content on ftp..."
	if [[ -z $dir ]]; then
		dir=""
	fi
	while true; do
		get_content "$dir"
		read -p " Enter number to expand directory or download? (x to exit) "
		# make sure number is inserted
		while ! [[ "$REPLY" =~ [0-9] ]] && [[ $REPLY != "x" ]]; do
			read -p " Enter number to expand directory or download? (x to exit) "
		done
		if [[ "$REPLY" == "x" ]]; then
			break
		fi			
		number=$REPLY
		if [[ $number -eq 0 ]]; then
			#remove last path component
			dir=$(dirname "$dir")
			continue
		else
			dir="$dir$(echo ${array_list[$number]} | awk '{print $9}')"
		fi
		read -p " Do you want to List or Download (0/1)? "
		if [[ $REPLY -eq 0 ]]; then
			# list new dir
			continue
		else
			# make download argument
			download_argument+=("--user=$username")
			download_argument+=("--path=/$dir")
			download_argument+=("--source=Manually")
			path="/$dir"
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
				continue_queue="false"
				option[1]="queue"
				main &> /dev/null &
			fi
			# unset the added path and stay in current directory.
			unset path download_argument
			dir=$(dirname "$dir")
		fi
	done
	if [[ -e "$queue_file" ]]; then
		read -p " Do you want to start the download (y/n)?"
		if [[ $REPLY == "y" ]]; then
			background=true
			main &> /dev/null &
		else
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
	echo "quit" >> "$$ftplist_file"
	$lftp -f "$ftplist_file" &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo "INFO: Listing content(s):"
		echo " Current path: $dir"
		old_dir="$dir"
		# remove /./ as it is not needed
		if [[ -f "$ftp_content" ]]; then
			sed "1d" -i "$ftp_content"
		fi
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