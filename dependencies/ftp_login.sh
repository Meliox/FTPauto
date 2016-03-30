#!/bin/bash
function ftp_login {
	if ((verbose)); then
		echo "debug 8 -t -o $lftpdebug" >> "$ftplogin_file"
	fi
		#Timeout settings
		echo "set net:timeout 10" >> "$ftplogin_file"
	#	echo "set net:max-retries 5" >> "$ftplogin_file"
	#	echo "set net:reconnect-interval-base 5" >> "$ftplogin_file"
	#	echo "set net:reconnect-interval-multiplier 2" >> "$ftplogin_file"
	if [[ $ssl == "true" ]]; then
		echo "set ftp:ssl-force true" >> "$ftplogin_file"
		echo "set ssl:verify-certificate false" >> "$ftplogin_file"
	fi
	if  [[ $transferetype =~ "upftp" ]] || [[ $transferetype =~ "downftp" ]] || [[ $transferetype =~ "fxp" ]]; then
		echo "open -u $ftpuser,$ftppass $ftphost -p $ftpport" >> "$ftplogin_file"
	else
		echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Have a look on your config (--user=$user --edit)!\e[00m\n"
		exit 1
	fi
}