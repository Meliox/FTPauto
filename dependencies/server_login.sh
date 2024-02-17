#!/bin/bash

# Prepare login based on transfer type
function load_login {
if [[ "$transferetype" == "upftp" || "$transferetype" == "downftp" || "$transferetype" == "fxp" ]]; then
    ftp_login $1
elif [[ "$transferetype" == "upsftp" ]]; then
    sftp_login
fi
}

# Function to generate FTP login details based on input (1 or 2)
function ftp_login {
    local number OIFS IFS ftpcustom ftpssl ftpuser ftppass ftphost ftppass ftploginfile
    number="$1"

    # Set variables based on input
    ftpcustom="ftpcustom${number}"
    ftpssl="ftpssl${number}"
    ftpuser="ftpuser${number}"
    ftppass="ftppass${number}"
    ftphost="ftphost${number}"
    ftpport="ftpport${number}"
    ftploginfile="ftplogin_file${number}"

    # Set timeout settings
    echo "set net:timeout 10" >> "${!ftploginfile}"
    echo "set net:max-retries 3" >> "${!ftploginfile}"
    echo "set net:reconnect-interval-base 10" >> "${!ftploginfile}"
    echo "set net:reconnect-interval-multiplier 1" >> "${!ftploginfile}"
    echo "set net:reconnect-interval-max 60" >> "${!ftploginfile}"

    # Write debug settings to file if verbose mode is enabled
    if ((verbose)); then
        echo "debug 8 -t -o $lftpdebug" >> "${!ftploginfile}"
    fi

    # Write SSL settings to file
    if [[ "${!ftpssl}" == true ]]; then
        echo "set ftp:ssl-force true" >> "${!ftploginfile}"
        echo "set ssl:verify-certificate false" >> "${!ftploginfile}"
    fi

    # Write custom configurations to file
    if [[ -n "${!ftpcustom}" ]]; then
        OIFS="$IFS"
        IFS=';'
        for i in "${!ftpcustom[@]}"; do
            echo "$i" >> "${!ftploginfile}"
        done
        IFS="$OIFS"
    fi

    # Allow only normal transfer types
    if [[ "$transferetype" =~ "upftp" ]] || [[ "$transferetype" =~ "downftp" ]] || [[ "$transferetype" =~ "fxp" ]]; then
        echo "open -u ${!ftpuser},${!ftppass} ${!ftphost} -p ${!ftpport}" >> "${!ftploginfile}"
    else
        echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Check your config (--user=$user --edit)!\e[00m\n"
        cleanup session
        cleanup end
        exit 1
    fi
}

# Function to generate SFTP login details
function sftp_login {
    # Set variables based on input
    sftpcustom="$sftpcustom"
    sftpuser="$sftpuser"
    sftppass="$sftppass"
    sftphost="$sftphost"
    sftpport="$sftpport"

    # Set timeout settings
    echo "set net:timeout 10" >> "${sftplogin_file}"
    echo "set net:max-retries 3" >> "${sftplogin_file}"
    echo "set net:reconnect-interval-base 10" >> "${sftplogin_file}"
    echo "set net:reconnect-interval-multiplier 1" >> "${sftplogin_file}"
    echo "set net:reconnect-interval-max 60" >> "${sftplogin_file}"

    echo "sftp:auto-confirm true" >> "${sftplogin_file}"

    # Write custom configurations to file
    if [[ -n "${sftpcustom}" ]]; then
        for option in "${sftpcustom[@]}"; do
            echo "$option" >> "${sftplogin_file}"
        done
    fi
    
    # Check if username and password are provided
    if [[ "$transferetype" =~ "upsftp" ]]; then
        echo "open -u ${sftpuser},${sftppass} sftp://${sftphost} -p ${sftpport}" >> "${sftplogin_file}"
    else
        echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Check your config (--user=$user --edit)!\e[00m\n"
        cleanup session
        cleanup end
        exit 1
    fi
}