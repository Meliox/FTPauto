#!/bin/bash

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

# Function to generate SFTP login details based on input (1 or 2)
function sftp_login {
    local number sftpcustom sftpuser sftppass sftphost sftpport sftploginfile
    number="$1"

    # Set variables based on input
    sftpcustom="sftpcustom${number}"
    sftpuser="sftpuser${number}"
    sftppass="sftppass${number}"
    sftphost="sftphost${number}"
    sftpport="sftpport${number}"
    sftploginfile="sftplogin_file${number}"

    # Set timeout settings
    echo "ConnectTimeout 10" >> "${!sftploginfile}"
    echo "ServerAliveInterval 30" >> "${!sftploginfile}"

    echo "sftp:connect-program ssh -a -x -oStrictHostKeyChecking=no" >> "${!sftploginfile}"

    # Write custom configurations to file
    if [[ -n "${!sftpcustom}" ]]; then
        for option in "${!sftpcustom[@]}"; do
            echo "$option" >> "${!sftploginfile}"
        done
    fi

    # Check if the custom SSH port is provided
    if [[ -n "${!sftpport}" ]]; then
        echo "Port ${!sftpport}" >> "${!sftploginfile}"
    fi

    
    # Check if username and password are provided
    if [[ -n "${!sftpuser}" ]] && [[ -n "${!sftppass}" ]]; then
        echo "User ${!sftpuser}" >> "${!sftploginfile}"
        echo "Password ${!sftppass}" >> "${!sftploginfile}"
    else
        echo "ERROR: Username or password not provided. Check your configuration." >&2
        exit 1
    fi

    # Specify the host to connect to
    if [[ -n "${!sftphost}" ]]; then
        echo "HostName ${!sftphost}" >> "${!sftploginfile}"
    else
        echo "ERROR: Host not provided. Check your configuration." >&2
        exit 1
    fi
}