#!/bin/bash
function ftp_login {
	local number OIFS IFS ftpcustom ftpssl ftpuser ftppass ftphost ftppass ftploginfile
	number="$1"
		#Timeout settings
	#	echo "set net:timeout 10" >> "$ftplogin_file$number"
	#	echo "set net:max-retries 5" >> "$ftplogin_file$number"
	#	echo "set net:reconnect-interval-base 5" >> "$ftplogin_file$number"
	#	echo "set net:reconnect-interval-multiplier 2" >> "$ftplogin_file$number"
	# corrcet variables
	ftpcustom="ftpcustom${number}"
	ftpssl="ftpssl${number}"
	ftpuser="ftpuser${number}"
	ftppass="ftppass${number}"
	ftphost="ftphost${number}"
	ftpport="ftpport${number}"
	ftploginfile="ftplogin_file${number}"
	# write custom config to file
	if ((verbose)); then
		echo "debug 8 -t -o $lftpdebug" >> "${!ftploginfile}"
	fi
	if [[ -n "${!ftpcustom}" ]]; then
		OIFS="$IFS"
		IFS=';'
		for i in "${!ftpcustom[@]}"; do
			echo "$i" >> "${!ftploginfile}"
		done
		IFS="$OIFS"
	fi
	# write ssl setting to file
	if [[ "${!ftpssl}" == true ]]; then
		echo "set ftp:ssl-force true" >> "${!ftploginfile}"
		echo "set ssl:verify-certificate false" >> "${!ftploginfile}"
	fi
	# only allow the normal transfere types
	if  [[ "$transferetype" =~ "upftp" ]] || [[ "$transferetype" =~ "downftp" ]] || [[ "$transferetype" =~ "fxp" ]]; then
		echo "open -u ${!ftpuser},${!ftppass} ${!ftphost} -p ${!ftpport}" >> "${!ftploginfile}"
	else
		echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Have a look on your config (--user=$user --edit)!\e[00m\n"
		cleanup sesssion
		cleanup end
		exit 1
	fi
}