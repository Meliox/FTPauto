#!/bin/bash

function f_split {
	local split_file="$1"
	#update transfer_path
	filepath=()
	changed_name=()
	# Splitting process
		echo "INFO: Splitting files into $tempdir"
		sed "5s#.*#***************************	Transfering: "$orig_name" - large file detected, splitting in progress #" -i $logfile
		mkdir "$tempdir"
		rar a -r -v"$splitsize"M -vn -m0 "$tempdir$orig_name".rar "$(basename "$split_file")" &> /dev/null
		filepath+=( "$tempdir" )
		changed_name+=( "$(basename "$tempdir")" )
		echo "INFO: Splitting done"
	# sfv process
	if [[ "$create_sfv" == "true" ]]; then
		echo "INFO: Creating checkfile"
		sed "5s#.*#***************************	Transfering: "$orig_name" - large file detected, creating sfv #" -i $logfile
		cksfv -b "$tempdir"* > "$tempdir$orig_name.sfv"
		echo "INFO: "$orig_name".sfv created"
	fi
}


function largefile {
#called with $filepath $exclude_array[@]
# Test if largest file is different from rar and that size is largest than $rarsplitlimit
	if [[ "$split_files" == "true" ]]; then
		echo -ne "INFO: Large file(s):"
		local dir="$1"
		local var=("${!2}")
		local lfile=()
		local exp=()
		if [[ -f "$dir" ]]; then
			# got a file
			if [[ $(stat --printf="%s" "$dir") -gt $(( $rarsplitlimit * 1024 *1024 )) ]]; then
				echo -ne "\e[00;32m found\e[00m \r"
				echo "INFO: Splitting transfer into $rarsplitlimit MB files..."
				cd "$(dirname "$orig_path")"
				f_split "$dir"
			fi
		else
			# got a directory
			# use filter to exclude files
				if [[ -n "$var" ]]; then
					for i in "${var[@]}"; do
						exp+=(-iname $i)
					done
					exp="( "${exp[@]}" -prune -o -type f )"
				fi
			# look for large files
				while IFS= read -r -d $'\0' file; do
					lfile[i++]="$file"
				done < <(find "$dir" $exp -type f -size +"$rarsplitlimit"M -print0)
			# process large file
			if [[ -n "${lfile[@]}" ]] && [[ ${#lfile[@]} -eq 1 ]]; then #ONLY one large file in directory
				echo "INFO: Largest file larger, larger than $rarsplitlimit MB, has to be split..."
				cd "$orig_path"
				f_split "$lfile"
				#look for all other files, and and them to transfer queue
					while IFS= read -r -d $'\0' file; do
						filepath[i++]="$file"
					done < <(find "$dir" $exp -type f -size -"$rarsplitlimit"M -print0)
			elif [[ ${#lfile[@]} -gt 1 ]]; then #SEVERAL large files
				echo "INFO: Several large files has been found and is split into same directory"
				cd "$orig_path"
				f_split "$dir"
			else
				echo -ne "\e[00;33m nothing found\e[00m \r"
				echo
			fi
		fi
	fi
}
