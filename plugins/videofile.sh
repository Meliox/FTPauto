#!/bin/bash

function videoFile {
	# Function to handle video files

	local found_files found_file_size_total found_file_size found_file_percentage

	# Check if the file is a single file and not a RAR archive
	if [[ -f "$filepath" ]] && ! [[ "$filepath" =~ (\.(rar)$) ]]; then
		# Single file passed, not compressed, continue
		msg plain "INFO: Single file passed (not compressed). Continuing..."
	elif [[ -f "$filepath" ]] && [[ "$filepath" =~ (\.(rar)$) ]]; then
		# A single RAR file is passed, investigate using rar mount
		msg plain "INFO: A RAR file is passed. Looking inside RAR file for video file(s)..."
		msg warning "INFO: Size calculations may be incorrect."
		mountsystem mount
	elif [[ -d "$filepath" ]]; then
		# Search and calculate the total size of all video files found to get the percentage of transfer that consists of video files
		found_files=()

		# Check for exclusions
		if [[ "${#exclude_array[@]}" -gt 0 ]] && [[ -n "${exclude_array[@]}" ]]; then
			while IFS=  read -r -d $'\0'; do
				found_files+=("$REPLY")
			done < <(find "$filepath" \( -type f \) -and \( -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" \) -and \! \( $exclude_expression \) -print0)
		else
			while IFS=  read -r -d $'\0'; do
				found_files+=("$REPLY")
			done < <(find "$filepath" \( -type f \) -and \( -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" \) -print0)
		fi

		# For found video files, evaluate their total size and if nothing is found try rar mount
		if [[ "${#found_files[@]}" -gt 0 ]]; then
			msg plain "INFO: ${#found_files[@]} video file(s) found:"
			found_file_size_total="0"
			for n in "${found_files[@]}"; do
				found_file_size=$(du -bs "$n" | awk '{print $1}')
				found_file_size_total=$(echo "$found_file_size_total + $found_file_size" | bc)
				msg plain "      $(basename "$n") $(echo "scale=2; $found_file_size / (1024*1024)" | bc)MB"
			done
			msg plain "INFO: Total size found: $(echo "scale=2; $found_file_size_total / (1024*1024)" | bc)MB."
			found_file_percentage=$(echo "scale=3; $found_file_size_total / $directorysize * 100" | bc | cut -d'.' -f1)
			if [[ $found_file_percentage -gt 80 ]]; then
				msg plain "INFO: File(s) found is ${found_file_percentage}% > 80%. Everything OK"

				# Update path and correct filename(s)
				if [[ "${#found_files[@]}" -eq 1 ]] && [[ -d "$filepath" ]]; then
					# One file is found in a directory
					# Rename file to top directory
					mkdir -p "$tempdir$orig_name"
					ln -s "${found_files[0]}" "$tempdir$orig_name/$(basename "$(dirname "${found_files[0]}")").${found_files[0]##*.}"
				elif [[ "${#found_files[@]}" -gt 1 ]]; then
					# Multiple files found, rename those to top directory
					for n in "${found_files[@]}"; do
						mkdir -p "$tempdir$orig_name"
						ln -s "$n" "$tempdir$orig_name/$(basename "$n")"
					done
				fi

				transfer_path="$tempdir$orig_name" # Update transfer path

				# Update filesize to be transferred
				get_size "$transfer_path"
			else
				msg plain "INFO: No large video file(s) found (> 80% of total size). Looking for RAR files containing video files..."
				mountsystem mount
			fi
		else
			msg plain "INFO: No video file(s) found. Looking for RAR files containing video files..."
			mountsystem mount
		fi
	fi
}

function mountsystem {
	# Function to handle mounting and unmounting RAR files

	if [[ -n "$rar2fs" ]]; then
		case "$1" in
			"mount" )
				# Search filepath for RAR file(s)
				local rarset found_files found_file_size_total found_file_size found_file_percentage
				rarset=()
				if [[ "${#exclude_array[@]}" -gt 0 ]] && [[ -n "${exclude_array[@]}" ]]; then
					while IFS=  read -r -d $'\0'; do
						rarset+=("$REPLY")
					done < <(find "$filepath" \! \( $exclude_expression \) -and \( -name '*.rar' \) -print0 | sort -z)
				else
					while IFS=  read -r -d $'\0'; do
						rarset+=("$REPLY")
					done < <(find "$filepath" \( -name '*.rar' \) -print0 | sort -z)
				fi
				if [[ "${#rarset[@]}" -gt 0 ]]; then
					msg plain "INFO: ${#rarset[@]} RAR file(s) found:"
					for i in "${rarset[@]}"; do
						msg plain "      $(basename $i)"
					done

					# Mount filepath with rar2fs in tempdir
					mkdir -p "$tempdir$orig_name-rarmount"
					"$rar2fs" "$filepath" "$tempdir$orig_name-rarmount" --seek-length=2 &> /dev/null

					# Used to unmount
					mount_in_use="true"

					# Search tempdir for video files
					found_files=()
					if [[ "${#exclude_array[@]}" -gt 0 ]] && [[ -n "${exclude_array[@]}" ]]; then
						while IFS=  read -r -d $'\0'; do
							found_files+=("$REPLY")
						done < <(find "$tempdir$orig_name-rarmount" \( -type f \) -and \( -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" \) -and \! \( $exclude_expression \) -print0)
					else
						while IFS=  read -r -d $'\0'; do
							found_files+=("$REPLY")
						done < <(find "$tempdir$orig_name-rarmount" \( -type f \) -and \( -name "*.avi" -or -name "*.mkv" -or -name "*.img" -or -name "*.iso" -or -name "*.mp4" \) -print0)
					fi

					# Verify that they make up 80% of everything
					if [[ "${#found_files[@]}" -gt 0 ]]; then
						msg plain "INFO: ${#found_files[@]} video file(s) found:"
						found_file_size_total="0"
						for n in "${found_files[@]}"; do
							found_file_size=$(du -bs "$n" | awk '{print $1}')
							found_file_size_total=$(echo "$found_file_size_total + $found_file_size" | bc)
							msg plain "      $(basename "$n") $(echo "scale=2; $found_file_size / (1024*1024)" | bc)MB"
						done
						found_file_percentage=$(echo "scale=3; $found_file_size_total / $directorysize * 100" | bc | cut -d'.' -f1)
						if [[ $found_file_percentage -gt 80 ]]; then
							# Video files were successfully found
							msg plain "INFO: File(s) found is ${found_file_percentage}% > 80%. Everything OK"

							# All video files are not correctly named, so that needs to be fixed.
							# A new directory is created and all files are symlinked with correct name
							for n in "${found_files[@]}"; do
								mkdir -p "$tempdir$orig_name/"
								directoryname="$(basename "$(dirname "$n")")"
								directoryname="${directoryname%-rarmount}"
								ln -s "$n" "$tempdir$orig_name/$directoryname.${n##*.}"
							done

							transfer_path="$tempdir$orig_name" # Update transfer path

							get_size "$transfer_path"
						else
							msg warning "INFO: No large video file(s) found (> 80% of total size)."
						fi
					else
						msg warning "INFO: No video file(s) found inside RAR file(s). File(s) will be transferred instead."
					fi
				else
					msg warning "INFO: No RAR file(s) are found in path."
				fi
				if [[ $mount_in_use != "true" ]]; then
					# System was unsuccessful in finding video files using mount, so it will revert to default transfer instead
					mountsystem umount
					msg plain "INFO: Ignoring send_option=video. Path will be transferred normally."
					send_option="default"
					msg plain "INFO: Sendoption: $send_option"
				fi
				;;
			"umount" )
				# Attempt to unmount directory
				local i
				i=1
				while :; do
					fusermount -u "$tempdir$orig_name-rarmount"
					local status=$?
					if [[ $status -eq 0 ]]; then
						msg plain "INFO: Mount directory has been unmounted"
						break
					elif [[ $status -ne 0 ]] && [[ $i -eq 3 ]]; then
						msg warning "\nINFO: Unmounting failed. Could not unmount files (try manually fusermount -u): \"$tempdir$orig_name-rarmount\" "
						break
					fi
					msg warning "\nINFO: Unmounting failed - $i attempt(s). Retrying in 10 seconds... "
					sleep 10
					let i++
				done
				;;
		esac
	else
		msg error "ERROR: rar2fs not found. Ignoring mount and transferring everything as normal"
		msg notice "INFO: Rerun installer to install rar2fs"
	fi
}