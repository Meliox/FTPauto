#!/bin/bash

function videoFile {
	found_file=( "$(find "$filepath" $exclude_expression -size 50M -type f -iname "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" | sort -n )" )
	if [[ -n $found_file ]]; then
		found_file_size_total="0"
		for n in "${found_file}"; do
			found_file_size=$(echo $(du -bs "$n") | awk '{print $1}')
			found_file_size_total=$(echo "$found_file_size_total + $found_file_size" | bc)
			echo "INFO: Found $(basename "$n") $(echo "$found_file_size / (1024*1024)" | bc)MB"
			# save found files in variable
			tempdir=( "$n" )
		done
		echo "INFO: Found total size: $(echo "$found_file_size_total / (1024*1024)" | bc)MB. "
		echo "INFO: Confirming that it is >80% of the total transfere"
		found_file_percentage=$(echo "scale=1; $found_file_size_total / $directorysize * 100" | bc)
		if [[ $found_file_percentage > 80 ]]; then
			echo "INFO: Is "$found_file_percentage"%. Everything OK"
			# update paths to main path --> temp path where everything is mounted
			filepath=( "$tempdir" )
			#Update filesize to be transfered
			size="$(echo "$found_file_size_total / (1024*1024)" | bc)"
			echo "INFO: Updated size to transfere(video file): "$size"MB"
		else
			echo "INFO: No videofile found. Trying mount..."
			mountsystem mount
		fi		
	else
		echo "INFO: No videofile found. Trying mount..."
		mountsystem mount
	fi
}

function mountsystem {
	if [[ -n "$rarfs" ]]; then
		case "$1" in
		"mount" )
			local temp_rarset rarset old_dirname dirname npath file fileset temp_name temppathset
			if [[ -d "$filepath" ]]; then
				rarset=( $(find "$filepath" $exclude_expression -name '*.rar' | sort -n) )
				if [[ ! -z "$rarset" ]]; then
					# used to exclude mouting same video, part01.rar, part02.rar, ..., in same folder
					# only use first one
					for n in "${rarset[@]}"; do
						dirname="$(basename $(dirname $n))"
						if [[ "$old_dirname" != "$dirname" ]]; then
								temp_rarset+=($n)
								old_dirname="$dirname"
						fi
					done
					rarset=( "${temp_rarset[@]}" )
					echo "INFO: Found ${#rarset[@]} rarfile(s), trying to find videofile(s)..."
					mkdir -p "$tempdir"
					for n in "${rarset[@]}"; do
						dirname="$(basename $(dirname $n))"
						if [[ ${#rarset[@]} -eq 1 ]]; then
							npath="$tempdir" # for single rar file
						else
							npath="$tempdir$dirname" # for multiple
							mkdir "$npath"
						fi
						$rarfs "$n" "$npath" &> /dev/null
						file=$(find "$npath" $exclude_expression -type f -iname "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4")
						if [[ ! -z "$file" ]]; then
							echo -e "\e[00;32m     $(basename $file) in $dirname\e[00m"
							fileset+=( "$file" )
							temp_name+=( "$dirname" ) # directory name
							temppathset+=( "$npath" ) # contains path files/directories to be send
							tempmountset+=( "$npath" ) # contains path to mounted directory, NOT LOCAL
							mount_in_use="true" # used to unmount
						else
							# Remove the noncontaining folder
							echo -e "\e[00;31mINFO: $(basename $n) doesn't contain any videofiles\e[00m"
							fusermount -u "$npath"
							local retries=0
							while [[ $? -eq 1 ]]; do
								let retries++
								if [[ $retries -eq 4 ]]; then
									echo -e "\e[00;31mINFO: $npath could not be unmounted\e[00m" 
									break
								fi
								sleep 3
								fusermount -u "$npath"
							done
							rm -r "$npath"
						fi
					done
					unset n
				if [[ $mount_in_use == "true" ]]; then
					# update paths to main path --> temp path where everything is mounted
					filepath=( "$tempdir" )
					changed_name=( "$(basename $tempdir)" )
					# update size to transfer
					get_size "$tempdir"
				fi
			else
				echo -e "\e[00;33mINFO: No rar has been found. Ignoring mount and transfering everything as normal\e[00m"
			fi
		fi
		;;
		"umount" )
			for n in "${tempmountset[@]}"; do
				fusermount -u "$n"
			done
			unset n
			echo -e "\e[00;32mINFO: Evertyhing has been unmounted\e[00m"
		;;
		esac
	else
		echo -e "\e[00;31mERROR: Rarfs not found. Ignoring mount and transfering everything as normal\e[00m"
		echo -e "\e[00;36mINFO: See http://ubuntuforums.org/showthread.php?t=573307 or install by apt-get install subversion automake1.9 fuse-utils libfuse-dev && cd rarfs && ./configure && make && make install && adduser <user> fuse && chgrp fuse /dev/fuse && chgrp fuse /bin/fusermount && chmod u+s /bin/fusermount\e[00m"
	fi
}
