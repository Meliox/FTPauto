#!/bin/bash

function largefile {
	# Splitting process
		echo "INFO: Splitting files into volumes $tempdir"
		sed "5s#.*#***************************	Transferring: ${orig_name} - Rar splitting, ${splitsize} MB pieces, in process#" -i $logfile
		if [[ -f "$filepath" ]]; then
			tempdir="$scriptdir/run/$username-temp/${orig_name%.*}/"
			mkdir -p "$tempdir"
			rar a -r -"v${splitsize}M" -vn -m0 "${tempdir}${orig_name%.*}.rar" "$filepath" &> /dev/null
		elif [[ -d "$filepath" ]]; then
			tempdir="$scriptdir/run/$username-temp/${orig_name}"
			mkdir -p "$tempdir"
			rar a -r -v"${splitsize}M" -vn -m0 "${tempdir}/${orig_name}.rar" "$filepath" &> /dev/null
		fi
		transfer_path="$tempdir" # update transfer path
		echo "INFO: Splitting into volumes done"
	# sfv process
	if [[ "$create_sfv" == "true" ]]; then
		echo "INFO: Creating sfv checkfile"
		sed "5s#.*#***************************	Transferring: ${orig_name} - Creating sfv #" -i $logfile
		if [[ -f "$filepath" ]]; then
			cksfv -b "$tempdir"* > "${tempdir}/${orig_name%.*}.sfv"
			echo "INFO: ${orig_name%.*}.sfv created"
		elif [[ -d "$filepath" ]]; then
			cksfv -b "$tempdir"* > "${tempdir}/${orig_name}.sfv"
			echo "INFO: ${orig_name%.*}.sfv created"
		fi
	fi
}
