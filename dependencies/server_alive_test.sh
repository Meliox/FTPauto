#!/bin/bash

# Function to confirm that the server is alive and writable
function online_test {
    online
    if [[ $? -eq 0 ]]; then
        writeable # Check if server is writable
    else
        if [[ -f "$server_alive_file" ]]; then rm "$server_alive_file"; fi;
        echo -e "\e[00;31m [RETRYING]\e[00m"
        retry_count="0"
        # Before download
        if [[ $confirm_online == "true" ]]; then
            # Continue trying according to settings
            quittime=$(( $scriptstart + $retry_download_max*60*60 )) # Hours
            echo "INFO: Keep trying until $(date --date=@$quittime)"
            if [[ $(date +%s) -lt $quittime ]]; then
                echo -e "INFO: Stopping session and trying again $retry_download"mins" later\n"
                cleanup session
                waittime=$(($retry_download*60))
                sed "3s#.*#***************************  SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i "$logfile"
                sleep 10
                queue run # Running new session
            fi
        fi
        # Online test
        while [[ $retry_count -lt $retries ]]; do
            echo -e "\e[00;31m [RETRYING]\e[00m"
            let retry_count++
            online
            if [[ $? -eq 0 ]]; then
                writeable
                is_online="0"
                break
            fi
        done
        # If still offline
        if [[ $is_online -ne 0 ]]; then
            sed "3s#.*#***************************	SERVER INFO: SERVER OFFLINE#" -i $logfile
            is_online="1"
        fi
    fi
}

# Function to check if the server is writable
function writeable_test {
    if [[ -f "$server_alive_file" ]]; then rm "$server_alive_file"; fi;
    echo -e "\e[00;32m [OK]\e[00m"
    # Confirm that path is writeable etc.
    echo -n "INFO: Checking if set path is writeable..."
    echo "Testing server settings for download" > "$server_check_testfile"
    cat "$login_file1" >> "$server_check_file"
    echo "put -O \"$incomplete\" \"$server_check_file\"" >> "$server_check_file"
    echo "rm \"$incomplete$(basename $server_check_file)\"" >> "$server_check_file"
    echo "quit" >> "$server_check_file"
    $lftp -f "$server_check_file" &> /dev/null
}

# Function to check if the server is online
function online {
    echo -n "INFO: Checking if server is alive..."
    exit
    # Returns 1 if server is offline, takes up to 1 min!
    cat "$login_file1" >> $server_alive_file
    echo "ls" >> $server_alive_file
    echo "quit" >> $server_alive_file
    $lftp -f "$server_alive_file" &> /dev/null
}

# Function to check if the server is writable
function writeable {
    writeable_test
    if [[ -f "$server_check_file" ]]; then rm "$server_check_file"; fi;
    if [[ $? -eq 0 ]]; then
        echo -e "\e[00;32m [OK]\e[00m"
        is_online="0"
    else
        echo -e "\e[00;32m [RETRYING]\e[00m"
        retry_count="0"
        # Before download
        if [[ $confirm_online == "true" ]]; then
            # Continue trying according to settings
            quittime=$(( $scriptstart + $retry_download_max*60*60 )) # Hours
            echo "INFO: Keep trying until $(date --date=@$quittime)"
            if [[ $(date +%s) -lt $quittime ]]; then
                echo -e "INFO: Stopping session and trying again $retry_download"mins" later\n"
                cleanup session
                waittime=$(($retry_download*60))
                sed "3s#.*#***************************  SERVER INFO: SERVER OFFLINE: DOWNLOAD POSTPONED! Trying again in "$waittime"mins#" -i "$logfile"
                sleep 10
                let retry_count++
                queue run # Running new session
            fi
        fi
        # Online test
        while [[ $retry_count -lt $retries ]]; do
            echo -e "\e[00;31m [RETRYING]\e[00m"
            let retry_count++
            writeable_test
        done
        # If still offline
        sed "3s#.*#***************************	SERVER INFO: SERVER NOT WRITEABLE#" -i $logfile
        is_online="1"
    fi
}