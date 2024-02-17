#!/bin/bash

function largefile {
	# Function to split large files and create SFV checkfiles

	# Splitting process
	echo "INFO: Splitting files into volumes $tempdir"

	# Update log file with information about the current process
	sed "5s#.*#***************************	Transferring: ${orig_name} - Rar splitting, ${splitsize} MB pieces, in process#" -i $logfile

	# Check if the file path exists
	if [[ -f "$filepath" ]]; then
		# If it's a file, create a temporary directory and split the file into volumes
		tempdir="$scriptdir/run/$username-temp/${orig_name%.*}/"
		mkdir -p "$tempdir"
		rar a -r -"v${splitsize}M" -vn -m0 "${tempdir}${orig_name%.*}.rar" "$filepath" &> /dev/null
	elif [[ -d "$filepath" ]]; then
		# If it's a directory, create a temporary directory and split the directory into volumes
		tempdir="$scriptdir/run/$username-temp/${orig_name}"
		mkdir -p "$tempdir"
		rar a -r -v"${splitsize}M" -vn -m0 "${tempdir}/${orig_name}.rar" "$filepath" &> /dev/null
	fi

	# Update transfer path
	transfer_path="$tempdir"

	echo "INFO: Splitting into volumes done"

	# SFV process
	if [[ "$create_sfv" == "true" ]]; then
		echo "INFO: Creating sfv checkfile"
		# Update log file with information about the current process
		sed "5s#.*#***************************	Transferring: ${orig_name} - Creating sfv #" -i $logfile

		# Create SFV checkfile
		if [[ -f "$filepath" ]]; then
			cksfv -b "$tempdir"* > "${tempdir}/${orig_name%.*}.sfv"
			echo "INFO: ${orig_name%.*}.sfv created"
		elif [[ -d "$filepath" ]]; then
			cksfv -b "$tempdir"* > "${tempdir}/${orig_name}.sfv"
			echo "INFO: ${orig_name%.*}.sfv created"
		fi
	fi
}
