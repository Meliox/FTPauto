#!/bin/bash

function videoFile {
	if [[ -f "$filepath" ]] && ! [[ "$filepath" =~ "\.(rar)$" ]]; then
		echo -e "\e[00;33mINFO: Single file found, which isn't compressed. Continuing...\e[00m"
	else
		# search and calculate total size of all video files found in found_file to get what percentage of transfer consists of videofiles
		found_files=()
		while IFS=  read -r -d $'\0'; do
			found_files+=("$REPLY")
			echo $REPLY
		done < <(find "$filepath" \( -type f \) -and \( -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" \) -and \! \( $exclude_expression \) -print0)
		if [[ -n ${found_files[0]} ]]; then
			found_file_size_total="0"
			for n in "${found_files[@]}"; do
				found_file_size=$(echo $(du -bs "$n") | awk '{print $1}')
				found_file_size_total=$(echo "$found_file_size_total + $found_file_size" | bc)
				echo "INFO: Found \"$(basename "$n")\" $(echo "scale=2; $found_file_size / (1024*1024)" | bc)MB"
				# save found files in variable
				local tempdir=( "$n" )
			done
			echo "INFO: Total size found: $(echo "scale=2; $found_file_size_total / (1024*1024)" | bc)MB. "
			echo "INFO: Confirming that it is >90% of the total size"
			found_file_percentage=$(echo "scale=3; $found_file_size_total / $directorysize * 100" | bc | cut -d'.' -f1)
			if [[ $found_file_percentage -gt 80 ]]; then
				echo "INFO: File is "$found_file_percentage"%. Everything OK"
				# update paths to main path --> temp path where everything is mounted
				filepath=( "$tempdir" )
				#Update filesize to be transferred
				size="$(echo "scale=2; $found_file_size_total / (1024*1024)" | bc)"
				echo "INFO: Updated size to transfer(video file): "$size"MB"
			else
				echo "INFO: No videofile(s) found. Looking for rarfiles containing videofiles..."
				mountsystem mount
			fi
		else
			echo "INFO: No videofile(s) found. Looking for rarfiles containing videofiles..."
			mountsystem mount
		fi
	fi
}

function mountsystem {
	if [[ -n "$rarfs" ]]; then
		case "$1" in
		"mount" )
			local temp_rarset rarset old_dirname dirname npath file fileset temp_name temppathset extension fixed_filename
			if [[ -d "$filepath" ]]; then
				rarset=()
				while IFS=  read -r -d $'\0'; do
					rarset+=("$REPLY")
				done < <(find "$filepath" \! \( $exclude_expression \) -and \( -name '*.rar' \) -print0 | sort -z)
				if [[ ! -z "$rarset" ]]; then
					# used to exclude mouting same video, part01.rar, part02.rar, ..., in same folder
					# only use first one
					for i in "${rarset[@]}"; do
						dirname="$(basename "$(dirname "$i")")"
						if [[ "$old_dirname" != "$dirname" ]]; then
							temp_rarset+=("$i")
							old_dirname="$dirname"
						fi
					done
					unset i
					rarset=( "${temp_rarset[@]}" )
					echo "INFO: Found ${#rarset[@]} rarfile(s), trying to find videofile(s)..."
					mkdir -p "$tempdir"
					for n in "${rarset[@]}"; do
						if [[ ${#rarset[@]} -eq 1 ]]; then
							# for single rar file
							npath="$tempdir"
							dirname="$(basename "$(dirname "$n")")"
						else
							local rardir="${n#$orig_path}"
							if [[ $(grep -o "/" <<<"$rardir" | wc -l) -eq 2 ]]; then
									# single directory with mulitple rarfiles in sub directory(ies). No rar in main directory
									# fix subdirectory so they use dash instead of slash
									rardir=${rardir#\/}
									rardir=$(echo $(dirname "$rardir") | sed -e 's/\//-/g')
							elif [[ $(grep -o "/" <<<"$rardir" | wc -l) -lt 2 ]] && [[ ${#rarset[@]} -gt 1 ]]; then
									# single directory, multiple rarfiles
									rardir="$(basename "$(dirname "$n")")"
									if [[ "$rardir" != "$orig_name" ]]; then
										# subdirectory in main directory
										local rardir="${n#$orig_path}"
										rardir="$(dirname "$rardir")"
									fi
							else
								echo -e "\e[00;31mERROR: Unsupported rarset\e[00m\n"
								cleanup die
							fi
							dirname="$rardir"
						fi
						npath="$tempdir$rardir"
						mkdir -p "$npath" # for multiple
						$rarfs "$n" "$npath" &> /dev/null
						file=$(find "$npath" $exclude_expression -type f -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" -or -name "*.rar")
						extension="$(basename "$file")" # get fileextension
						extension="${extension##*.}"						
						if [[ -z "$file" ]]; then
							# Remove the noncontaining folder
							echo -e "\e[00;31mINFO: $(basename "$n") doesn't contain any videofiles\e[00m"
							sleep 3
							fusermount -u "$npath"
							local retries=0
							while [[ $? -eq 1 ]]; do
								let retries++
								if [[ $retries -eq 4 ]]; then
									echo -e "\e[00;31mINFO: "$npath" could not be unmounted\e[00m" 
									break
								fi
								sleep 3
								fusermount -u "$npath"
							done
							rm -r "$npath"
						elif [[ "$extension" =~ (mp4|avi|mkv|iso|img) ]]; then
							echo -e "\e[00;32m     $dirname > $(basename "$file")\e[00m"
						elif [[ "$extension" =~ (rar|zip) ]]; then
							echo -e "\e[00;33m     $dirname > $(basename "$file") (another compressed file - will be transferred)\e[00m"
						fi
						fileset+=( "$file" ) # path to videofiles
						temp_name+=( "$dirname" ) # directory names
						temppathset+=( "$npath" ) # contains path files/directories to be send
						tempmountset+=( "$npath" ) # contains path to mounted directory, NOT LOCAL
						fixed_filename+=( "$dirname.$extension" )
						mount_in_use="true" # used to unmount						
					done
					unset n
				if [[ $mount_in_use == "true" ]]; then
					# update paths to main path --> temp path where everything is mounted
					filepath=( "${fileset[@]}" )
					mountdirnames=( "${fixed_filename[@]}" )
					# update size to transfer
					get_size "$tempdir"
				fi
			else
				echo -e "\e[00;33mINFO: No rarfile(s) has been found. Ignoring mount and transferring everything as normal\e[00m"
				send_option="default"
			fi
		fi
		;;
		"umount" )
			for n in "${tempmountset[@]}"; do
				fusermount -u "$n"
			done
			unset n
			echo -e "\e[00;32m\nINFO: Everything has been unmounted\e[00m"
		;;
		esac
	else
		echo -e "\e[00;31mERROR: Rarfs not found. Ignoring mount and transferring everything as normal\e[00m"
		echo -e "\e[00;36mINFO: See http://ubuntuforums.org/showthread.php?t=573307 or install by apt-get install subversion automake1.9 fuse-utils libfuse-dev && cd rarfs && ./configure && make && make install && adduser <user> fuse && chgrp fuse /dev/fuse && chgrp fuse /bin/fusermount && chmod u+s /bin/fusermount\e[00m"
	fi
}
