#!/bin/bash
s_version="0.2.5"
verbose="0" #0 Normal info | 1 debug console | 2 debug into logfile
script="$(readlink -f $0)"
scriptdir=$(dirname $script)

control_c() {
	# run if user hits control-c
	echo -ne '\n'
	cleanup die
}
trap control_c SIGINT

function verbose {
	#todo fix verbose in external scripts
	if [[ $quiet ]]; then
		#silent
		exec > /dev/null 2>&1
	elif [[ ! $quiet ]] && [[ $verbose == 1 ]]; then
		echo "STARTING PID=$BASHPID"
		set -x
	elif [[ ! $quiet ]] && [[ $verbose == 2 ]]; then
		#verbose
		echo "INFO: Debugging. All input is redirected to logfile. Script is finished when console is idle again. Please wait!"
		exec 2>> "$scriptdir/run/$username.ftpauto.debug"
		echo "STARTING PID=$BASHPID"
		set -x
	elif [[ $quiet ]] && [[ $verbose != 0 ]]; then
		echo -e "\e[00;31mERROR: Verbose and silent can't be used at the same time\e[00m"
		exit 0
	fi
}
# load verbose
verbose

function start_ftpmain {
	# used to start ftpmain script and set proper debug level
	source "$scriptdir/dependencies/ftp_main.sh"
	if [[ $verbose -eq 1 ]]; then
		start_main "${download_argument[@]}"
	elif [[ $verbose -eq 2 ]]; then
		start_main "${download_argument[@]}" >> "$ftpmaindebugfile"
	else
		if [[ $background == "true" ]]; then
			download_argument+=("&> /dev/null &")
		fi		
		start_main "${download_argument[@]}"
	fi	
}

function confirm_queue_file {
	if [[ ! -f "$queue_file" ]]; then
		message "$1" "$2"
	fi
}

function confirm_lock_file {
	if [[ ! -f "$lockfile" ]]; then
		message "$1" "1"
	fi
}

function message {
	if [[ "$2" == "1" ]]; then
		echo -e "\e[00;31m$1\e[00m"
	else
		echo -e "\e[00;32m$1\e[00m"
	fi
	echo
	exit "$2"
}

function show_help {
	echo ""
	echo "Manual for controlscript"
	echo "  The purpose of this controlscript is the control ftp_main i.e. do the"
	echo "   following stuff instead easily. This is meant as an addon, but is not required for"
	echo "   the use of ftp_main"
	echo ""
	echo "  The following arguments are available"
	echo "  IMPORTANT: Controling the following"
	echo "    Default is always used if none of the following is set"
	echo "     --user=<USER> control the USER choosen"
	echo ""
	echo -e "\e[00;34m== Session manipulation ==\e[00m"	
	echo "      --pause | Terminates ftp_main and leaves queue intact"
	echo "      --stop | Terminates ftp_main and remove queue and current id"
	echo "      --start | Executes ftp_main and let it finish queue"
	echo "      --online | Returns if server is online or not"
	echo ""
	echo -e "\e[00;34m== Item manipulation ==\e[00m"
	echo "      --list | Lists all items in queue"
	echo "      = Required ="
	echo "       --id=<id> | id for <ITEM> you want to manipulate. Find them in the queuefile. See --list "
	echo "      = Options ="
	echo "       --up | Move Id Up"
	echo "       --down | Move Id down"
	echo "       --forget | remove Id from queue"
	echo "       --clear | Remove everything in queue"
	echo "      --delay | Delays transfer until X. Has to be in this format \"01/01/2010 12:00\" (Month/Day/Year 24h-time)"
	echo "       --queue | Sends <ITEM> to queue WITHOUT starting script if autostart=false in config. NOTE that --path <ITEM> is required for this to work"
	echo "         --path=~/home | Only used for --queue"
	echo -e "         --source <SOURCE> | Source is used to show how the download has been started. The\n           following is possible:\n           MANDL=manual download(if nothing is used)\n           WEBDL=download from webpage\n           FLXDL=autodownload from flexget\n           other can be used as well..."
	echo ""
	echo -e "\e[00;34m== User manipulation ==\e[00m"
	echo "      --add | Add user --add=<USER>"
	echo "      --remove | Removes all user history."
	echo "      --purge | Removes all user history and configs."	
	echo ""
	echo -e "\e[00;34m== Optional ==\e[00m"	
	echo "      --quiet | supresses all output"
	echo ""
	echo
}

function load_help {
	if [[ -e "$scriptdir/dependencies/help.sh" ]]; then
		source "$scriptdir/dependencies/help.sh"
	else
		echo -e "\e[00;31mError: /dependencies/help.sh is\n needed in order for this program to work\e[00m";
		exit 1
	fi
}

function load_user {
	if [[ -z "$username" ]] && [[ -f "$scriptdir/users/default/config" ]]; then
		username="default"
		config_name="$scriptdir/users/default/config"
		source "$scriptdir/users/$username/config"
		echo "INFO: User: $username"			
	elif [[ -n "$username" ]] && [[ -f "$scriptdir/users/$username/config" ]]; then
		username="$username"
		config_name="$scriptdir/users/$username/default"
		source "$scriptdir/users/$username/config"
		echo "INFO: User: $username"	
	elif [[ $option == "add" ]]; then
		# manually add user
		if [[ -z "$username" ]]; then
			username="default"
		else
			username="$username"
		fi
	else
		# user used not found, want to create them
		if [[ -z "$username" ]]; then
			echo -e "\e[00;31mERROR: No config found for default\e[00m"
			read -p "Do you want to create config for default user (y/n)? "
			if [ "$REPLY" == "y" ]; then
				username="default"
				option="add"
			else
				echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
				echo
				exit 1
			fi
		elif [[ -n "$username" ]]; then
			echo -e "\e[00;31mERROR: No config found for user=$username\e[00m"
			read -p "Do you want to create config for $username user (y/n)? "
			if [ "$REPLY" == "y" ]; then
				username="$username"
				option="add"
			else
				echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
				echo
				exit 1			
			fi		
		fi
	fi
	# confirm that config is most recent version
	if [[ $config_version -lt "2" ]]; then
		echo -e "\e[00;31mERROR: Config is out-dated, please update it. See --help for more info!\e[00m"
		echo -e "\e[00;31mIt has to be version 2\e[00m"
		cleanup session
		cleanup end
		exit 0
	fi	
}

function invalid_arg {
echo -e "\e[00;31mInvalid input for argument '$@'\e[00m"
echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
echo
exit 1
}

function option_manage {
if [[ -z ${option[0]} ]]; then
	option="$1"
else
	echo -e "\e[00;31mError: An option, --${option[0]} is already used. Only use one. Exiting...\e[00m"
	echo
	exit 1
fi
}
################################################### CODE BELOW #######################################################

echo
echo -e "\e[00;34mFTPauto script - $s_version\e[00m"
echo


download_argument=()
if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified\e[00m"; echo "See --help for more information"; echo ""; exit 0; fi
while :
do
	case "$1" in
		# Session
		--pause ) option_manage pause; shift;;
		--stop ) option_manage stop; shift;;
		--start ) option_manage start; shift;;
		# User
		--add ) option_manage add; shift;;
		--edit ) option_manage edit; shift;;
		--purge ) option_manage purge; shift;;
		--user ) if (($# > 1 )); then user=$2; download_argument+=("--username=$username"); else invalid_arg "$@"; fi; shift 2;;
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
		--queue ) option[1]=queue; shift;;
		--delay ) if (($# > 1 )); then delay=\"$2\"; download_argument+=("--delay=$delay"); else invalid_arg "$@"; fi; shift 2;;
		--delay=* ) delay=${1#--delay=}; download_argument+=("--delay=$delay"); shift;;
		--sort ) if (($# > 1 )); then sortto="$2"; download_argument+=("--sortto=$sortto"); else invalid_arg "$@"; fi; shift 2;;
		--sort=* ) sortto=${1#--sort=}; download_argument+=("--sortto=$sortto"); shift;;
		--path ) if (($# > 1 )); then option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; filepath="$2"; download_argument+=("--path=$filepath"); else invalid_arg "$@"; fi; shift 2;;
		--path=* ) option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; filepath="${1#--path=}"; download_argument+=("--path=$filepath"); shift;;
		--source=* ) source=${1#--source=}; download_argument+=("--source=$source"); if [[ -z $source ]]; then show_help; exit 1; fi; shift;;
		--source | -s ) if (($# > 1 )); then source=\"$2\"; download_argument+=("--source=$source"); else invalid_arg "$@"; fi; shift 2;;
		# Other
		--help | -h ) show_help; exit 1;;
		--verbose | -v) verbose=1; shift;;
		--debug ) verbose=2; shift;;
		--quiet) quiet=true; shift;;
		--bg) background=true; shift;;
		--progress) option=progress; shift;;
		--online ) option=online; shift;;
		--force ) download_argument+=("--force"); shift;;
		--freespace ) option=freespace; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; download_argument+=("--exec_post"); shift;;
		--exec_post ) if (($# > 1 )); then exec_post="$2"; download_argument+=("--exec_post"); else invalid_arg "$@"; fi; shift 2;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; download_argument+=("--exec_pre"); shift;;
		--exec_pre ) if (($# > 1 )); then exec_pre="$2"; download_argument+=("--exec_pre"); else invalid_arg "$@"; fi; shift 2;;		
		--test ) option=( "download" "start"); download_argument+=("--test"); shift;;
		-* ) echo -e "\e[00;31mInvalid option: $@\e[00m"; echo "Try viewing --help"; exit 0;;
		* ) break ;;
		--) shift; break;;
	esac
done

# load verbose level
verbose
echo "INFO: Information level: $verbose"

# load user
load_user

#Load dependencies
source "$scriptdir/dependencies/setup.sh"
setup

# Execute the given option
echo "INFO: Option(s): ${option[@]}"
case "${option[0]}" in
	"add" ) # add user
		load_help; write_config
		read -p " Do you want to configure that user now(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			nano "$scriptdir/users/$username/config"
		else
			echo "You can edit the user, by editing \"$scriptdir/users/$username/config\""
		fi		
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: User=\"$username\" added." "0"
	;;
	"edit" ) # edit user config
		nano "$scriptdir/users/$username/config"	
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: User=\"$username\" edited." "0"
	;;	
	"remove" ) # remove all userfiles log files
		# remove all userfiles log files from /run and /user/$username/
		rm -f "$scriptdir/run/$username*"
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Userfiles removed for $username." "0"
	;;
	"purge" ) # remove all userfiles log files and config from /run and /user/$username/
		confirm_lock_file "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Can't remove $username while session is running." "1"
		rm -r -f "$scriptdir/users/$username"
		rm -f "$scriptdir/run/$username"
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: User=\"$username\" removed." "0"
	;;
	"pause" ) # Stop transfer
		confirm_lock_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, lockfile couldn't be found. Nothing could be done!" "1"
		cleanup stop
		cleanup session
		cleanup end
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has been terminated." "0"
	;;
	"stop" ) # Stop transfer and remove queue
		confirm_lock_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, lockfile couldn't be found. Nothing could be done!" "1"
		cleanup stop
		cleanup session
		cleanup end
		rm "$queue_file"
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has been terminated." "0"
	;;
	"start" ) # start session from queue file
		if [[ ! -e "$queue_file" ]]; then
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Nothing in queue." "1"
		fi	
		start_ftpmain
		if [[ $background == "true" ]]; then
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has started." "0"
		elif [[ $? -eq 1 ]]; then
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Succeded." "0"
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Failed." "1"
		fi
	;;	
	"download" )
		# set source
		if [[ -z $source ]]; then
			source="CONSOLE"
		else
			source="$source"
		fi	
		# start download right away
		if [[ ${option[1]} == "start" ]]; then
			start_ftpmain
			if [[ $background == "true" ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session in background has started." "0"
			elif [[ $? -eq 0 ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Succeded." "0"
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Failed." "1"
			fi
		# queue download
		# TODO: Add options to queuefile as well
		elif [[ ${option[1]} == "queue" ]]; then
			# If autostart is used, then try and execute main script. Always in background
			if [[ $autostart == "true" ]]; then
				background="true"
				start_ftpmain
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has started." "0"
			else
				# determine if item exists already
				if [[ -e "$queue_file" ]]; then
					if [[ -n $(cat "$queue_file" | grep $(basename "$filepath")) ]]; then
						message "INFO: Item already exists. Doing nothing. Exiting..." "1"
					fi
					# find id to <ITEM>
					id=$(( $(tail -1 "$queue_file" | cut -d'#' -f1) + 1 ))
				else # no queue files exists
					id="1"
				fi
				# get transfer size
				if [[ "$transferetype" == "downftp" ]]; then
					echo "INFO: Looking up size on ftp..."
				elif [[ "$transferetype" == "upftp" ]]; then
					if [[ ! -d "$filepath" ]] || [[ ! -f "$filepath" ]] && [[ -z $(find "$filepath" -type f) ]]; then
						message "$(date '+%d/%m/%y-%a-%H:%M:%S'): ERROR: Option --path is required with existing path and has to contain file(s).\n See --help for more info!!" "1"
						exit 1
					fi
				fi
				get_size "$filepath" "exclude_array[@]" &> /dev/null
				
				echo "$id#$source#$filepath#$size"MB"#$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
				message "INFO: Adding $(basename "$filepath") to queue with id=$id" "0"
			fi
		fi
	;;
	"list" ) # list content of queue file
		confirm_queue_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): --$option: Empty queue!" "0"
		while read line; do
			id=$(echo $line | cut -d'#' -f1)
			source=$(echo $line | cut -d'#' -f2)
			path=$(echo $line | cut -d'#' -f3)
			size=$(echo $line | cut -d'#' -f4)
			time=$(echo $line | cut -d'#' -f5)
			echo $id $source $path $size $time
		done < "$queue_file"
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): List has been shown." "0"
	;;	
	"clear" ) # clear content of queue file
		confirm_queue_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, queue could not be found." "1"
		rm "$queue_file"
		message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Queue removed." "0"
	;;	
	"forget" ) # remove item with <ID> from queue
		confirm_queue_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, queuefile couldn't be found. Nothing could be removed!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			#make sure id exists and is present in queue
			echo "Removing id=$id"
			sed "/^"$id"\#/d" -i "$queue_file" #ex -s -c '%s/^[0-9]*//|wq' file.txt if your ex is actually symlinked to the installed vim, then you can use \d and \+
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id=$id removed from queue."	"0"
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id=$id selected/in queue." "1"
		fi
	;;
	"up" ) # Move item with <ID> 1 up in queue
		confirm_queue_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, queuefile couldn't be found. Nothing could be moved!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			line_info=$(cat "$queue_file" | grep "^$id#")
			line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)			
			previous_line_number=$(($line_number -1))
			if [[ "$line_number" -lt "2" ]]; then
				#if id is the first, keep it there
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id, $id, is at top." "0"
			else
				sed "/^"$id"\#/d" -i "$queue_file"
				sed "$previous_line_number i $line_info" -i "$queue_file"
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Moved Id=$id, up." "0"
			fi
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id=$id, selected/in queue." "1"
		fi		
	;;
	"down" ) # Move item with <ID> 1 down in queue
		confirm_queue_file "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, queuefile couldn't be found. Nothing could be moved!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			line_info=$(cat "$queue_file" | grep "^$id#")
			line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)
			next_line_number=$(($line_number +1))
			last_line=$(cat "$queue_file" | grep -ne '' | cut -d':' -f1 | tail -n1 )
			if [[ $next_line_number -eq $last_line ]]; then
				#add id to the end of file
				sed "/^"$id"\#/d" -i "$queue_file"
				echo $line_info >> "$queue_file"
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id=$id, is at the buttom." "0"
			elif [[ $next_line_number -gt $last_line ]]; then
				#if id is the last, do nothing
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id=$id, is at the buttom." "1"
			else
				#any other cases
				sed "/^"$id"\#/d" -i "$queue_file"
				sed "$next_line_number i $line_info" -i "$queue_file"
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Moved Id=$id, down." "0"
			fi
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id, $id, selected/in queue." "1"
		fi
	;;
	"online" ) # Perform server test
		source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
		source "$scriptdir/dependencies/ftp_online_test.sh" && online_test
		cleanup session
		if [[ $is_online -eq 0 ]]; then
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): Server is OK" "0"
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): Server is NOT OK" "1"
		fi
	;;
	"freespace" ) # check free space
		source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
		source "$scriptdir/dependencies/ftp_size_management.sh" && ftp_sizemanagement info
		cleanup session
		if [[ $is_online -eq 1 ]]; then
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Could " "1"
		else
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is responding" "0"
		fi
	;;
	"progress" ) # write out download progress
		echo "INFO: Keeps updating every 60 second. Exit with \"x\""
		if [ -t 0 ]; then stty -echo -icanon time 0 min 0; fi
		keypress=""
		while [[ "x$keypress" == "x" ]]; do
			info=$(sed -n '5p' < "$logfile" | egrep -o 'Transfering.*')
			if [[ -z "info" ]]; then
				echo "INFO: Nothing is transfered!"
				break
			fi
			echo -ne $info \(last update $(date '+%H:%M:%S')\) '\r'
			sleep 1
			read keypress
		done
		if [ -t 0 ]; then stty sane; fi
		echo -e '\n'
		message "$(date '+%d/%m/%y-%a-%H:%M:%S'): Progress finished" "0"
	;;	
	* )
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): No options selected." "1"
	;;
esac
