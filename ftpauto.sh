#!/bin/bash
s_version="0.6.2"
verbose="0" #0 Normal info | 1 debug console | 2 debug into logfile
script="$(readlink -f "$0")"
scriptdir=$(dirname $script)
lastUpdate=1511410224
message=""

control_c() {
	# run if user hits control-c
	echo -ne '\n'
	cleanup die
}
trap control_c SIGINT

function verbose {
	# Function to control verbosity of script output
	
	# Check if 'quiet' flag is set
	if [[ $quiet ]]; then
		# If 'quiet' flag is set, redirect all output to /dev/null
		exec > /dev/null 2>&1
	# Check if 'verbose' flag is set to 1
	elif [[ ! $quiet ]] && [[ $verbose -eq 1 ]]; then
		# If 'verbose' flag is set to 1, enable shell tracing and display starting message
		echo "STARTING PID=$BASHPID"
		set -x
	# Check if 'verbose' flag is set to 2
	elif [[ ! $quiet ]] && [[ $verbose -eq 2 ]]; then
		# If 'verbose' flag is set to 2, redirect stderr to debug logfile, enable shell tracing, and display starting message
		echo "INFO: Debugging. All input is redirected to logfile. Script is finished when console is idle again. Please wait!"
		exec 2>> "$scriptdir/run/$username.ftpauto.debug"
		echo "STARTING PID=$BASHPID"
		set -x
	# Check if 'quiet' flag is set and 'verbose' flag is not set to 0
	elif [[ $quiet ]] && [[ $verbose -ne 0 ]]; then
		# If both 'quiet' and 'verbose' flags are set, display an error message and exit
		echo -e "\e[00;31mERROR: Verbose and silent can't be used at the same time\e[00m\n"
		exit 0
	fi
}

# load verbose
verbose

function updateChecker {
	# Check if it's time to perform an update check
	if [[ $(date +'%s') -gt $((lastUpdate + 14*24*60*60)) ]]; then
		echo -n "INFO: Checking for update ..."
		# Retrieve the latest release version from GitHub
		local release=$(curl --silent https://github.com/Meliox/FTPauto/releases | grep -o 'FTPauto-v[0-9.]*tar.gz' | sort -V | tail -1)
		release_version=${release#"FTPauto-v"}
		release_version=${release_version%.tar.gz}
		# Compare the latest release version with the installed version
		if [[ "$release_version" == "$s_version" ]]; then
			# If the versions match, notify that it's the latest version
			echo -e " \e[00;32m [Latest]\e[00m"
			# Clear any previous update messages
			sed "7c message=\"\"" -i "$script"
		else
			# Split version numbers into arrays for comparison
			local IFS=.
			local n1=($release_version) n2=($s_version)
			for i in "${!n1[@]}"; do
				if [[ "${n1[i]}" -gt "${n2[i]}" ]]; then
					# If a newer version is found, notify and update the message
					echo -e "\e[00;33m [$release_version available. Consider updating]\e[00m"
					sed "7c message=\"INFO: New version ($release_version) available. Consider updating (execute bash install.sh update)\"" -i "$script"
					break
				elif [[ "${n1[i]}" -lt "${n2[i]}" ]]; then
					# If the installed version is newer, notify it's the latest version and clear the message
					echo -e " \e[00;32m [Latest]\e[00m"
					sed "7c message=\"\"" -i "$script"
					break
				fi
			done
		fi
		# Update the last update timestamp
		sed "6c lastUpdate=$(date +'%s')" -i "$script"
	else
		# If it's not time for an update check, display any existing message
		if [[ -n $message ]]; then
			echo -e "\e[00;33m$message\e[00m"
		fi
	fi
}

# Function to load dependencies based on input
function loadDependency {
    # Set the path for the dependency based on the input
    local LoadPath=""
    case "$1" in
        DConfig) LoadPath="$scriptdir/users/$username/config";;
        DServerList) LoadPath="$scriptdir/dependencies/server_list.sh";;
        DServerLogin) LoadPath="$scriptdir/dependencies/server_login.sh";;
        DServerMain) LoadPath="$scriptdir/dependencies/transfer_main.sh";;
        DServerAliveTest) LoadPath="$scriptdir/dependencies/server_alive_test.sh";;
        DLargeFile) LoadPath="$scriptdir/plugins/largefile.sh";;
        DServerSizeManagement) LoadPath="$scriptdir/dependencies/server_size_management.sh";;
        DHelp) LoadPath="$scriptdir/dependencies/help.sh";;
        DPushOver) LoadPath="$scriptdir/plugins/pushover.sh";;
        DSetup) LoadPath="$scriptdir/dependencies/setup.sh";;
        DSort) LoadPath="$scriptdir/dependencies/sorting.sh";;
        DVideoFile) LoadPath="$scriptdir/plugins/videofile.sh";;
    esac
    # Source the dependency
    source "$LoadPath"
}

# Function to start the transfer main script with appropriate debug level
function start_transfermain {
    # Load the transfer main dependency
    loadDependency DServerMain
    
    # Check the verbose level and start the main script accordingly
    if [[ $verbose -eq 1 ]]; then
        start_main "${download_argument[@]}"
    elif [[ $verbose -eq 2 ]]; then
        start_main "${download_argument[@]}" >> "$maindebugfile"
    else
        # Run in background or run normally
        if [[ $background == "true" ]]; then
            start_main "${download_argument[@]}" &> /dev/null &
        else
            start_main "${download_argument[@]}"
        fi
    fi
}

# Function to confirm the existence of files or locks
function confirm {
    case "$1" in
        queue_file )
            # Check if the queue file exists and display message if it doesn't
            if [[ ! -f "$queue_file" ]]; then
                message "$2" "$3"
            fi
            ;;
        lock_file )
            # Check if the lock file exists and display message if it doesn't
            if [[ ! -f "$lockfile" ]]; then
                message "$2" "$3"
            fi
            ;;
    esac
}

# Function to display messages with different colors based on the severity level
function message {
    if [[ "$2" -eq "1" ]]; then
        # Display message in red for error
        echo -e "\e[00;31m$(date '+%d/%m/%y-%a-%H:%M:%S'): $1\e[00m\n"
    else
        # Display message in green for success
        echo -e "\e[00;32m$(date '+%d/%m/%y-%a-%H:%M:%S'): $1\e[00m\n"
    fi
    # Exit with the provided exit code
    exit "$2"
}

# Function to load user configuration
function load_user {
    if [[ -z "$username" && -f "$scriptdir/users/default/config" ]]; then
        # If username is not provided and default configuration exists, use default user
        username="default"
        config_name="$scriptdir/users/default/config"
        loadDependency DConfig
        echo "INFO: User: $username"
    elif [[ -n "$username" && -f "$scriptdir/users/$username/config" ]]; then
        # If username is provided and corresponding configuration exists, use provided user
        username="$username"
        config_name="$scriptdir/users/$username/default"
        loadDependency DConfig
        echo "INFO: User: $username"
    elif [[ $option == "add" ]]; then
        # Manually add user
        if [[ -z "$username" ]]; then
            username="default"
        else
            username="$username"
        fi
    else
        # User used not found, prompt to create them
        echo -e "\e[00;31mERROR: No user found. See --help for more info.\e[00m\n"
        exit 1
    fi
    # Confirm that config is most recent version
    if [[ $config_version -ne "7" && $option != "add" && $option != "edit" ]]; then
        echo -e "\e[00;31mERROR: Please update it to version 6. See --help for more info!\e[00m\n"
        exit 1
    fi
}

# Function to handle invalid arguments
function invalid_arg {
    echo -e "\e[00;31mERROR: Invalid input for argument '$@'. See --help for more info.\e[00m\n"
    exit 1
}

# Function to manage options
function option_manage {
    if [[ -z ${option[0]} ]]; then
        option="$1"
    else
        echo -e "\e[00;31mERROR: An option, --${option[0]} is already used. Only one can be used.\e[00m\n"
        exit 1
    fi
}

# Function to handle main operations
function main {
    safelock="true"
    case "${option[0]}" in
        "add" ) # Add user
            loadDependency DHelp
            write_config
            read -p " Do you want to configure that user now(y/n)? "
            if [[ "$REPLY" == "y" ]]; then
                nano "$scriptdir/users/$username/config"
            else
                echo "You can edit the user later, by editing \"$scriptdir/users/$username/config\""
            fi
            create_log_file
            message "User=$username added." "0"
            ;;
        "edit" ) # Edit user config
            nano "$scriptdir/users/$username/config"
            message "User=$username edited." "0"
            ;;
        "remove" ) # Remove all userfiles generated files. Does not remove config
			rm -rf "$scriptdir/run/$username*"
			rm "$scriptdir/users/$username/log"
            message "Userfiles removed for $username." "0"
            ;;
        "purge" ) # Remove all userfiles log files and config from /run and /user/$username/
            rm -rf "$scriptdir/users/$username"
            rm -rf "$scriptdir/run/$username*"
            message "User=$username removed." "0"
            ;;
        "pause" ) # Stop transfer
            safelock="false"
            confirm lock_file "Error, lockfile couldn't be found. Nothing could be done!" "1"
            cleanup stop
            cleanup session
            cleanup end
            message "Session has been terminated." "0"
            ;;
        "stop" ) # Stop transfer and remove queue
            safelock="false"
            confirm lock_file "Error, lockfile couldn't be found. Nothing could be done!" "1"
            cleanup stop
            cleanup session
            cleanup end
            rm "$queue_file"
            message "Session has been terminated." "0"
            ;;
        "start" ) # Start session from queue file
            safelock="false"
            if [[ ! -e "$queue_file" ]]; then
                message "Nothing in queue." "1"
            fi
            start_transfermain
            if [[ $background == "true" ]]; then
                message "Session has started." "0"
            elif [[ $? -eq 1 ]]; then
                message "Succeeded." "0"
            else
                message "Failed." "1"
            fi
            ;;
        "retry" ) # Resets all failed downloads so that they can be retried
            confirm queue_file "Empty queue!" "0"
            mv "$queue_file" "${queue_file}.old"
            while read line; do
                id=$(echo $line | cut -d'|' -f1)
                source=$(echo $line | cut -d'|' -f2)
                path=$(echo $line | cut -d'|' -f3)
                sort=$(echo $line | cut -d'|' -f4)
                size=$(echo $line | cut -d'|' -f5)
                failed=$(echo $line | cut -d'|' -f6)
                time=$(echo $line | cut -d'|' -f7)
                echo "$id|$source|$path|$sort|$size|false|$time" >> "$queue_file"
            done < "${queue_file}.old"
            rm "${queue_file}.old"
            message "OK." "0"
            ;;
        "download" ) # Download or queue download
            safelock="false"
            if [[ -z $source ]]; then
                source="CONSOLE"
            else
                source="$source"
            fi
            if [[ ${option[1]} == "start" ]]; then
                start_transfermain
                if [[ $background == "true" ]]; then
                    message "Session in background has started." "0"
                elif [[ $? -eq 0 ]]; then
                    message "Succeeded." "0"
                else
                    message "Failed." "1"
                fi
            elif [[ ${option[1]} == "queue" ]]; then
                start_transfermain "${download_argument[@]}" --queue
            fi
            ;;
        "list" ) # List content of queue file
            confirm queue_file "Empty queue!" "0"
            echo "ID|PATH|SORT TO|SIZE(MB)|FAILED STATUS|TIME"
            while read line; do
                id=$(echo $line | cut -d'|' -f1)
                source=$(echo $line | cut -d'|' -f2)
                path=$(echo $line | cut -d'|' -f3)
                sort=$(echo $line | cut -d'|' -f4)
                size=$(echo $line | cut -d'|' -f5)
                failed=$(echo $line | cut -d'|' -f6)
                time=$(echo $line | cut -d'|' -f7)
                echo "$id|$source|$path|$sort|$size|$failed|$time"
            done < "$queue_file"
            message "List has been shown." "0"
            ;;
        "clear" ) # Clear content of queue file
            confirm queue_file "Error, queue could not be found." "1"
            rm "$queue_file"
            message "Queue removed." "0"
            ;;
        "forget" ) # Remove item with <ID> from queue
            confirm queue_file "Error, queuefile couldn't be found. Nothing could be removed!" "1"
            if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id") ]]; then
                echo "Removing id=$id"
                sed "/^"$id"/d" -i "$queue_file"
                message "Id=$id removed from queue." "0"
            else
                message "No Id=$id selected/in queue." "1"
            fi
            ;;
        "up" ) # Move item with <ID> 1 up in queue
            confirm queue_file "Error, queuefile couldn't be found. Nothing could be moved!" "1"
            if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id") ]]; then
                line_info=$(cat "$queue_file" | grep "^$id")
                line_number=$(cat "$queue_file" | grep -ne "^$id" | cut -d':' -f1)
                previous_line_number=$(($line_number -1))
                if [[ "$line_number" -lt "2" ]]; then
                    message "Id, $id, is at top." "0"
                else
                    sed "/^"$id"/d" -i "$queue_file"
                    sed "$previous_line_number i $line_info" -i "$queue_file"
                    message "Moved Id=$id, up." "0"
                fi
            else
                message "No Id=$id, selected/in queue." "1"
            fi
            ;;
        "down" ) # Move item with <ID> 1 down in queue
            confirm queue_file "Error, queuefile couldn't be found. Nothing could be moved!" "1"
            if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id") ]]; then
                line_info=$(cat "$queue_file" | grep "^$id")
                line_number=$(cat "$queue_file" | grep -ne "^$id" | cut -d':' -f1)
                next_line_number=$(($line_number +1))
                last_line=$(cat "$queue_file" | grep -ne '' | cut -d':' -f1 | tail -n1 )
                if [[ $next_line_number -eq $last_line ]]; then
                    sed "/^"$id"/d" -i "$queue_file"
                    echo $line_info >> "$queue_file"
                    message "Id=$id, is at the buttom." "0"
                elif [[ $next_line_number -gt $last_line ]]; then
                    message ": Id=$id, is at the buttom." "1"
                else
                    sed "/^"$id"/d" -i "$queue_file"
                    sed "$next_line_number i $line_info" -i "$queue_file"
                    message "$option: Moved Id=$id, down." "0"
                fi
            else
                message "$option: No Id, $id, selected/in queue." "1"
            fi
            ;;
        "online" ) # Perform server test
            loadDependency DServerAliveTest && online_test
            if [[ $is_online -eq 0 ]]; then
                message "Server is OK" "0"
            else
                message "Server is NOT OK" "1"
            fi
            ;;
        "freespace" ) # Check free space
            loadDependency DServerSizeManagement && server_sizemanagement info
            if [[ $is_online -eq 1 ]]; then
                message "$option: Could " "1"
            else
                message "$option: Server is responding" "0"
            fi
            ;;
        "progress" ) # Write out download progress
			# Confirm the existence of the lock file; if not found, display an error message
			confirm lock_file "Error: Lockfile not found. Nothing is being transferred!" "1"

			echo "INFO: Transferring: $(sed -n 5p < "$logfile" | cut -d',' -f1 | cut -d' ' -f3)"

			# Display information about the update frequency
			echo "INFO: Updates every $sleeptime second. (Exit with 'x')"

			# Disable echo and canonical mode for user input
			if [ -t 0 ]; then 
				stty -echo -icanon time 0 min 0
			fi

			# Initialize keypress variable and count
			keypress=""
			local count=0

			# Loop until 'x' key is pressed
			while [[ "x$keypress" == "x" ]]; do
				# Extract transfer progress information from the logfile
				local title="$(sed -n 5p < "$logfile" | cut -d',' -f1 | cut -d' ' -f2)"
				local percentage="$(sed -n 5p < "$logfile" | cut -d',' -f2 | cut -d' ' -f2)"
				percentage="${percentage%\%}"
				local TimeDiff="$(sed -n 5p < "$logfile" | cut -d',' -f3 | cut -d' ' -f3)"
				local Speed="$(sed -n 5p < "$logfile" | cut -d',' -f4 | cut -d' ' -f2)"
				local SpeedAverage="$(sed -n 5p < "$logfile" | cut -d',' -f6 | cut -d' ' -f2)"
				local etatime="$(sed -n 5p < "$logfile" | cut -d',' -f5 | cut -d' ' -f3)"
				
				# Check if any transfer is in progress
				if [[ -z "$(sed -n 5p < "$logfile" | grep Transferring)" ]]; then
					echo "INFO: No ongoing transfer."
					break
				fi
				
				# Update progress bar
				if [[ $count -gt 0 ]]; then
					tput cuu 1
					tput el1
				fi
				local cols=$(($(tput cols) - 2))
				local percentagebarlength=$(echo "scale=0; $percentage * $cols / 100" | bc)
				local string="$(eval printf "=%.0s" '{1..'"$percentagebarlength"'}')"
				local string2="$(eval printf "\ %.0s" '{1..'"$(($cols - $percentagebarlength - 1))"'}')"
				if [[ $percentagebarlength -eq 0 ]]; then
					printf "\r[$string2]      (no transfer information yet) ($(date '+%H:%M:%S'))"
				else
					printf "\r[$string>$string2]      $percentage%% ETA ${etatime}@${speed}MB/s. ${TransferredNewMB}MB@${SpeedAverage}MB/s(avg). ($(date '+%H:%M:%S'))"
				fi
				
				# Increment count and wait for 1 second
				let count++
				sleep 1
				
				# Read user input (keypress)
				read keypress
			done

			# Restore terminal settings if applicable
			if [ -t 0 ]; then 
				stty sane
			fi

			# Print newline character for clarity
			echo -e '\n'

			# Display completion message
			message "Progress finished" "0"
			;;
        "dir" ) # List content of server and download it
            loadDependency DServerList && remote_server_list
            message "Closing filebrowser" "0"
            ;;
        * )
            message "No options selected." "1"
            ;;
    esac
}

################################################### CODE BELOW ########################################################

echo -e "\n\e[00;34mFTPauto script - $s_version\e[00m\n"

download_argument=()
if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified. See --help for more info.\e[00m\n"; exit 0; fi
while :; do
	case "$1" in
		# Session
		--pause ) option_manage pause; shift;;
		--stop ) option_manage stop; shift;;
		--start ) option_manage start; shift;;
		# User
		--add ) option_manage add; shift;;
		--edit ) option_manage edit; shift;;
		--purge ) option_manage purge; shift;;
		--user ) if (($# > 1 )); then user=$2; download_argument+=("--user=$username"); else invalid_arg "$@"; fi; shift 2;;
		--user=* ) username=${1#--user=}; download_argument+=("--user=$username"); shift;;
		# Item
		--forget ) option_manage forget; shift;;
		--list ) option_manage list; shift;;
		--remove ) option_manage remove; shift;;
		--up ) option_manage up; shift;;
		--down ) option_manage down; shift;;
		--id ) if (($# > 1 )); then id=$2; else invalid_arg "$@"; fi; shift 2;;
		--id=* ) id=${1#--id=}; shift;;
		--clear ) option_manage clear; shift;;
		# Options
		--queue ) download_argument+=("--queue"); shift;;
		--delay ) if (($# > 1 )); then delay="$2"; download_argument+=("--delay=$delay"); else invalid_arg "$@"; fi; shift 2;;
		--delay=* ) delay=${1#--delay=}; download_argument+=("--delay=$delay"); shift;;
		--sort ) if (($# > 1 )); then sortto="$2"; download_argument+=("--sortto=$sortto"); else invalid_arg "$@"; fi; shift 2;;
		--sort=* ) sortto=${1#--sort=}; download_argument+=("--sortto=$sortto"); shift;;
		--path ) if (($# > 1 )); then option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; path="$2"; download_argument+=("--path=$path"); else invalid_arg "$@"; fi; shift 2;;
		--retry ) option[0]=retry; shift;;
		--path=* ) option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; path="${1#--path=}"; path=${path%/}; download_argument+=("--path=$path"); shift;;
		--source=* ) source=${1#--source=}; download_argument+=("--source=$source"); if [[ -z $source ]]; then invalid_arg "$@"; exit 1; fi; shift;;
		--source | -s ) if (($# > 1 )); then source="$2"; download_argument+=("--source=$source"); else invalid_arg "$@"; fi; shift 2;;
		# Other
		--help | -h ) loadDependency DHelp; show_help; exit 1;;
		--verbose | -v) verbose=1; shift;;
		--debug ) verbose=2; shift;;
		--quiet) quiet=true; shift;;
		--bg) background=true; shift;;
		--progress) option=progress; shift;;
		--online ) option=online; shift;;
		--dir=* ) dir=${1#--dir=}; option=dir; shift;;
		--dir ) option=dir; if (($# > 1 )); then dir="$2"; fi; shift;;
		--force ) download_argument+=("--force"); shift;;
		--freespace ) option=freespace; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; download_argument+=("--exec_post"); shift;;
		--exec_post ) if (($# > 1 )); then exec_post="$2"; download_argument+=("--exec_post"); else invalid_arg "$@"; fi; shift 2;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; download_argument+=("--exec_pre"); shift;;
		--exec_pre ) if (($# > 1 )); then exec_pre="$2"; download_argument+=("--exec_pre"); else invalid_arg "$@"; fi; shift 2;;
		--test ) option=( "download" "start"); download_argument+=("--test"); shift;;
		-* ) echo -e "\e[00;31mERROR: Invalid argument '$@'. See --help for more info.\e[00m\n"; exit 0;;
		* ) break;;
		--) shift; break;;
	esac
done

# load verbose level
verbose
echo "INFO: Information level: $verbose"

# check for new version
updateChecker

# load user
load_user

# Load dependencies
loadDependency DSetup
setup

# make sure user has a log file
if [[ ! -e "$logfile" && "${option[0]}" != add ]]; then
	loadDependency DHelp; create_log_file
fi

# Execute the given option
echo "INFO: Option(s): ${option[@]}"
main