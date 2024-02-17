#!/bin/bash
# Function to list content on a remote server and interactively navigate it

function remote_server_list {
    echo "INFO: Looking up content on remote server..."
    # Set default directory to root if not specified
    [[ -z $dir ]] && dir="/"
    
    while true; do
        # Get content of current directory
        get_content "$dir"
        
        # Prompt user for input
        read -p "Enter number to expand directory or download by also adding a \"d\", e.g., 1d ? (x to exit) "

        # Ensure valid input
        while ! [[ "$REPLY" =~ [0-9] ]] && [[ $REPLY != "x" ]]; do
            read -p "Enter number to expand directory or download by also adding a \"d\", e.g., 1d ? (x to exit) "
        done

        number=$REPLY

        # Exit if user inputs 'x'
        if [[ "$number" == "x" ]]; then
            break
        elif [[ "$number" == "0" ]]; then
            # Go to top path
            dir="/"
            continue
        elif [[ "$number" == "1" ]]; then
            # Move up one directory
            dir=$(dirname "$dir")
            continue
        elif [[ "$number" =~ ^[0-9]+d ]]; then
            # Extract number and prepare for download
            number=${number%d}
            path="$dir$(echo ${array_list[$number]} | awk '{print $9}')"
            download_argument+=("--user=$username" "--path=/$path" "--source=Manually")
            option=("download" "queue")
            echo " Adding $path to queue"
            main
            unset path download_argument option  # Unset variables
        else
            # Check if selected item is a directory
            if [[ "$(echo ${array_list[$number]} | awk '{print $5}')" -gt 4096 ]]; then
                echo -e "\e[00;31m Cannot expand file: $(echo ${array_list[$number]} | awk '{print $9}')\e[00m"
                continue
            fi
            # Expand selected directory
            dir="$dir$(echo ${array_list[$number]} | awk '{print $9}')/"
            continue
        fi
    done

    # Prompt to start download if queue file exists
    if [[ -e "$queue_file" ]]; then
        read -p "Do you want to start the download (y/n)? "
        if [[ $REPLY == "y" ]]; then
            read -p "Do you wish to execute it as a background thread (y/n)? "
            [[ $REPLY == "y" ]] && background=true
            start_transfermain
        fi
    fi
}

# Function to retrieve content from a remote server and display it
function get_content {
    # Remove old files first
    rm -f "$ftplist_file"
    loadDependency DServerLogin && server_login 1  # Generate a new login file as download removes it
    cat "$ftplogin_file1" >> "$ftplist_file"
    echo "ls -aFl \"${dir}\" > ~/../..$ftp_content" >> "$ftplist_file"
    echo "quit" >> "$ftplist_file"
    $lftp -f "$ftplist_file" &> /dev/null

    # Check if listing was successful
    if [[ $? -eq 0 ]]; then
        echo -e "\n\e[00;32mINFO: Listing content(s):\e[00m"
        echo "Current path: $dir"
        old_dir="$dir"
        array_list=( )
        readarray array_list < "$ftp_content"
        array_list=( "X X X X 4096 Feb XX XX ." "X X X X 4096 Feb XX XX .." "${array_list[@]}" )
        i=0
        # Iterate over array and display content
        for value in "${array_list[@]}"; do
            if [[ $(echo $value | awk '{print $5}') -eq 4096 ]]; then
                # Directory
                printf "%-8s\n" "$i : $(($(echo $value | awk '{print $5}')/(1024*1024)))MB $(echo -e "\e[00;34m$(echo $value | awk '{print $9}')\e[00m")"
            else
                # File
                printf "%-8s\n" "$i : $(($(echo $value | awk '{print $5}')/(1024*1024)))MB $(echo $value | awk '{print $9}')"
            fi
            let i++
        done | column -c 1 -t
    fi

    # Cleanup
    rm -f "$ftplist_file" "$ftp_content" "$ftplogin_file1"
}
