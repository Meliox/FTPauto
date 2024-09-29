#!/bin/bash

# Prepare login based on transfer type
function load_login {
    if [[ "$transferetype" == "upftp" || "$transferetype" == "downftp" || "$transferetype" == "fxp" ]]; then
        ftp_login $1
    elif [[ "$transferetype" == "upsftp" ]]; then
        sftp_login $1
    fi
}

# Function to generate FTP login details based on input (1 or 2)
function ftp_login {
    local number OIFS IFS custom ssl user pass host pass loginfile
    number="$1"

    # Set variables based on input
    custom="ftpcustom${number}"
    ssl="ftpssl${number}"
    user="ftpuser${number}"
    pass="ftppass${number}"
    host="ftphost${number}"
    port="ftpport${number}"
    login_file="login_file${number}"

    # Set timeout settings
    echo "set net:timeout 10" >> "${!login_file}"
    echo "set net:max-retries 3" >> "${!login_file}"
    echo "set net:reconnect-interval-base 10" >> "${!login_file}"
    echo "set net:reconnect-interval-multiplier 1" >> "${!login_file}"
    echo "set net:reconnect-interval-max 60" >> "${!login_file}"

    # Write debug settings to file if verbose mode is enabled
    if ((verbose)); then
        echo "debug 8 -t -o $lftpdebug" >> "${!login_file}"
    fi

    # Write SSL settings to file
    if [[ "${!ssl}" == true ]]; then
        echo "set ftp:ssl-force true" >> "${!login_file}"
        echo "set ssl:verify-certificate false" >> "${!login_file}"
    fi

    # Write custom configurations to file
    write_custom_configurations "${!custom}" "${!login_file}"

    # Allow only normal transfer types
    if [[ "$transferetype" =~ "upftp" ]] || [[ "$transferetype" =~ "downftp" ]] || [[ "$transferetype" =~ "fxp" ]]; then
        echo "open -u ${!user},${!pass} ${!host} -p ${!port}" >> "${!login_file}"
    else
        echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Check your config (--user=$user --edit)!\e[00m\n"
        cleanup session
        cleanup end
        exit 1
    fi
}

# Function to generate SFTP login details
function sftp_login {
    local number OIFS IFS custom ssl user pass host pass loginfile sftpkeyfile
    number="$1"

    # Set variables based on input
    custom="sftpcustom${number}"
    ssl="sftpssl${number}"
    user="sftpuser${number}"
    pass="sftppass${number}"
    host="sftphost${number}"
    port="sftpport${number}"
    login_file="login_file${number}"
    sftpkeyfile="sftpkey${number}"

    # Set timeout settings
    echo "set net:timeout 10" >> "${!login_file}"
    echo "set net:max-retries 3" >> "${!login_file}"
    echo "set net:reconnect-interval-base 10" >> "${!login_file}"
    echo "set net:reconnect-interval-multiplier 1" >> "${!login_file}"
    echo "set net:reconnect-interval-max 60" >> "${!login_file}"

    echo "set sftp:auto-confirm true" >> "${!login_file}"

    if [[ -n "${!sftpkeyfile}" ]]; then
        echo "set ssl:key-file ${!sftpkeyfile}" >> "${!login_file}"
    fi
    
    # Write custom configurations to file
    write_custom_configurations "${!custom}" "${!login_file}"

    # Check if username and password are provided
    if [[ "$transferetype" =~ "upsftp" ]]; then
        echo "open -u ${!user},${!pass} sftp://${!host} -p ${!port}" >> "${!login_file}"
    else
        echo -e "\e[00;31mERROR: Transfer-option \"$transferetype\" not recognized. Check your config (--user=$user --edit)!\e[00m\n"
        cleanup session
        cleanup end
        exit 1
    fi
}

function write_custom_configurations {
    local custom_variable_name login_file_variable_name
    custom_variable_name="$1"
    login_file_variable_name="$2"

    # Write custom configurations to file
    if [[ -n "${custom_variable_name}" ]]; then
        IFS=';' read -ra custom_arr <<< "${custom_variable_name}"  # Split the string by ';' into an array
        for option in "${custom_arr[@]}"; do
            echo "$option" >> "${login_file_variable_name}"  # Append each option to the login file
        done
    fi
}
