#!/bin/bash
function ftp_login {
	# generate ftp login details based in input. The argument passed is (1 or 2).
	local number OIFS IFS ftpcustom ftpssl ftpuser ftppass ftphost ftppass ftploginfile
	number="$1"
	# correct variables so that they can be loaded properly later
	ftpcustom="ftpcustom${number}"
	ftpssl="ftpssl${number}"
	ftpuser="ftpuser${number}"
	ftppass="ftppass${number}"
	ftphost="ftphost${number}"
	ftpport="ftpport${number}"
	ftploginfile="ftplogin_file${number}"
	# set timeout settings
	echo "set net:timeout 10" >> "${!ftploginfile}"
	echo "set net:max-retries 3" >> "${!ftploginfile}"
	echo "set net:reconnect-interval-base 10" >> "${!ftploginfile}"
	echo "set net:reconnect-interval-multiplier 1" >> "${!ftploginfile}"
	echo "set net:reconnect-interval-max 60" >> "${!ftploginfile}"
	# write custom configurations to file, will overwrite any of above settings
	if ((verbose)); then
		echo "debug 8 -t -o $lftpdebug" >> "${!ftploginfile}"
	fi
        # write ssl setting to file
        if [[ "${!ftpssl}" == true ]]; then
                echo "set ftp:ssl-force true" >> "${!ftploginfile}"
                echo "set ssl:verify-certificate false" >> "${!ftploginfile}"
        fi
	if [[ -n "${!ftpcustom}" ]]; then
		OIFS="$IFS"
		IFS=';'
		for i in "${!ftpcustom[@]}"; do
			echo "$i" >> "${!ftploginfile}"
		done
		IFS="$OIFS"
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
