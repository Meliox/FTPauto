#!/bin/bash
s_version="0.2"
verbose=0 #0 Normal info | 1 debug console | 2 debug into logfile
script="$(readlink -f $0)"
scriptdir=$(dirname $script)

control_c() {
        # run if user hits control-c
		echo -ne '\n'
		cleanup die
}
trap control_c SIGINT

function message {
	if [[ "$2" == "1" ]]; then
		echo -e "\e[00;31m$1\e[00m"
	else
		echo -e "\e[00;32m$1\e[00m"
	fi
	echo
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

################################################### CODE BELOW #######################################################

echo
echo -e "\e[00;34mFTP DOWNLOAD SCRIPT - $s_version\e[00m"
echo

if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified\e[00m"; echo "See --help for more information"; echo ""; exit 0; fi
while :
do
	case "$1" in
		# Session
		--pause ) option=pause; shift;;
		--stop ) option=stop; shift;;
		--start ) if [[ -z ${option[0]} ]]; then option=( "start" "start"); else option[1]="start"; fi; shift;;
		# User
		--add ) option=add; shift;;
		--edit ) option=edit; shift;;
		--purge ) option=purge; shift;;
		--user ) if (($# > 1 )); then user=$2; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--user=* ) user=${1#--user=}; shift;;		
		# Item
		--quiet ) quiet=true; shift;;
		--forget ) option[0]=forget; shift;;
		--queue ) option[1]="queue"; shift;;
		--list ) option[0]=list; shift;;
		--remove ) option[0]=remove; shift;;
		--source=* ) source=${1#--source=}; if [[ -z $source ]]; then show_help; exit 1; fi; shift;;
		--source | -s ) if (($# > 1 )); then source=$2; if [[ -z $source ]]; then show_help; exit 1; fi; else echo "Invalid option for argument '$@'"; show_help; exit 1; fi; shift 2;;		
		--up ) option[0]=up; shift;;
		--down ) option[0]=down; shift;;
		--id ) if (($# > 1 )); then id=$2; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--id=* ) id=${1#--id=}; shift;;
		--sort ) if (($# > 1 )); then sortto="$2"; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--sort=* ) sortto=${1#--id=}; shift;;		
		--clear ) option[0]=clear; shift;;
		--path ) if (($# > 1 )); then option=( "queue" "start"); filepath="$2"; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--path=* ) option=( "queue" "start"); filepath="${1#--path=}"; shift;;		
		# Other
		--help | -h ) show_help; exit 1;;
		--verbose | -v) verbose=1; shift;;
		--debug ) verbose=2; shift;;
		--quiet) quiet=true; shift;;
		--online ) option=online; shift;;
		--freespace ) option=freespace; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; shift;;
		--exec_post ) if (($# > 1 )); then exec_post="$2"; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; shift;;
		--exec_pre ) if (($# > 1 )); then exec_pre="$2"; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;		
		--test ) option=test; shift;;
		-* ) echo -e "\e[00;31mInvalid option: $@\e[00m"; echo "Try viewing --help"; exit 0;;
		* ) break ;;
		--) shift; break;;
	esac
done
if [[ $quiet ]]; then
	#silent
	exec > /dev/null 2>&1
elif [[ ! $quiet ]] && [[ $verbose == 1 ]]; then
	echo "STARTING PID=$BASHPID"
	set -x	
elif [[ ! $quiet ]] && [[ $verbose == 2 ]]; then
	#verbose
	exec 2>> $scriptdir/run/$user.control.debug
	echo "STARTING PID=$BASHPID"
	set -x
elif [[ $quiet ]] && [[ $verbose != 0 ]]; then
	echo -e "\e[00;31mERROR: Verbose and silent can't be used at the same time\e[00m"
	exit 0
fi

if [[ -z "$user" ]] && [[ -f "$scriptdir/users/default/config" ]]; then
	echo "INFO: Loading default config"
	username="default"
	config_name="$scriptdir/users/default"
elif [[ -n "$user" ]] && [[ -f "$scriptdir/users/$user/config" ]]; then
	echo "INFO: Loading config: \"$user\""
	source "$scriptdir/users/$user/config"
	username="$user"
elif [[ $option == "add" ]]; then
	# manually add user
	if [[ -z "$user" ]]; then
		username="default"
	else
		username="$user"
	fi
else
	# user used not found, want to create them
	if [[ -z "$user" ]]; then
		echo -e "\e[00;31mERROR: No config found for default\e[00m"
		read -p "Do you want to create config for default user (y/n)?"
		if [ "$REPLY" == "y" ]; then
			username="default"
			option="add"
		else
			echo -e "\e[00;31mYou may want to have a look on help, --help\e[00m"
			exit 1
		fi
	elif [[ -n "$user" ]]; then
		echo -e "\e[00;31mERROR: No config found for user=$user\e[00m"
		read -p "Do you want to create config for $user user (y/n)?"
		if [ "$REPLY" == "y" ]; then
			username="$user"
			option="add"
		else
			echo -e "\e[00;31mYou may want to have a look on help, --help\e[00m"
			exit 1			
		fi		
	fi
fi
#Load dependencies
source "$scriptdir/dependencies/setup.sh"
setup

# Execute the given option
case "${option[0]}" in
	"add" )
		load_help; write_config
		read -p " Do you want to configure that user now(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			nano "$scriptdir/users/$username/config"
		else
			echo "You can edit the user, by editing \"$scriptdir/users/$user/config\""
		fi		
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: User=\"$username\" added." "0"		
		exit 0
	;;
	"edit" )
		nano "$scriptdir/users/$user/config"	
		exit 0
	;;	
	"remove" )
			# remove all userfiles log files from /run and /user/$user/
			if [[ -f "$lockfile" ]]; then
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Can't remove userfiles for $username while session is running." "1"
				exit 1
			fi
			rm -f "$scriptdir/run/$username*"
			message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Userfiles removed for $username." "0"
			exit 0
	;;
	"purge" )
			# remove all userfiles log files and config from /run and /user/$user/
			if [[ -f "$lockfile" ]]; then
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Can't remove $username while session is running." "1"
				exit 1
			fi
			rm -r -f "$scriptdir/users/$username"
			rm -f "$scriptdir/run/$username*"
			message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: User=\"$username\" removed." "0"
			exit 0
	;;
	"pause" )
			if [[ -f "$lockfile" ]]; then
				# clean up everything
				cleanup stop
				cleanup session
				cleanup end
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has been terminated." "0"
				exit 0
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, lockfile couldn't be found. Nothing could be done!" "1"
				exit 1
			fi
	;;
	"stop" )
			if [[ -f "$lockfile" ]]; then
				cleanup stop
				cleanup session
				cleanup end
				rm "$queue_file"
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has been terminated." "0"
				exit 0
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, lockfile couldn't be found. Nothing could be done!" "1"
				exit 1
			fi
	;;
	"list" )
			if [[ -f "$queue_file" ]]; then
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): Listing queued item for user" "0"
				while read line
				do
					id=$(echo $line | cut -d'#' -f1)  
					source=$(echo $line | cut -d'#' -f2)
					path=$(echo $line | cut -d'#' -f3)
					size=$(echo $line | cut -d'#' -f4)
					time=$(echo $line | cut -d'#' -f5)
					echo $id $source $path $size $time
				done < "$queue_file"
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: List has been shown." "0"
				exit 0				
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, queuefile couldn't be found. Nothing could be showed!" "1"
				exit 1
			fi
	;;
	"queue" )
			if [[ ! -d "$filepath" ]] || [[ ! -f "$filepath" ]] && [[ -z $(find "$filepath" -type f) ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): ERROR: Option --path is required with existing path and has to contain file(s).\n See --help for more info!!" "1"
				exit 1
			fi
			# start download
			if [[ ${option[1]} == "start" ]]; then
					exe="bash "$scriptdir/dependencies/ftp_main.sh" --user="$username" --path="$filepath" --sort="$sortto" --source="$source" --exec_post="$exec_post" --exec_pre="$exec_post" --delay="$delay""
				if [[ $force == "true" ]]; then
					eval "$exe" --force
				else
					eval "$exe"
				fi
			# queue download
			# TODO: Add options to queuefile as well
			elif [[ ${option[1]} == "queue" ]]; then
				get_size "$filepath" "exclude_array[@]" &> /dev/null
				if [[ -e "$queue_file" ]]; then
					if [[ -n $(cat $queue_file | grep $(basename $filepath)) ]]; then
						echo "INFO: Item already exists. Doing nothing. Exiting..."
						exit 0
					fi
					# find id to <ITEM>
					id=$(( $(tail -1 $queue_file | cut -d'#' -f1) + 1 ))
				else # no queue files exists
					id="1"
				fi
				# set source
				if [[ -z $source ]]; then
					source="CONSOLEQ"
				else
					source=$source"Q"
				fi
				echo "INFO: Adding $(basename $filepath) to queue with id=$id"
				echo "$id#$source#$filepath#$size"MB"#$(date '+%d/%m/%y-%a-%H:%M:%S')" >> $queue_file
				
				# If autostart is used, then try and execute main script
					if [[ $autostart == "true" ]]; then
						if [[ -f "$lockfile" ]]; then
							# check if lockfile is present, in order to determine if we should start script
							mypid_script=$(sed -n 1p "$lockfile")
							kill -0 $mypid_script
							if [[ $? -eq 1 ]]; then
								echo "INFO: No lockfile detected"
								rm "$lockfile"
								if [[ "$username" == "default" ]]; then
									bash "$scriptdir/dependencies/ftp_main.sh" &> /dev/null &
								else
									bash "$scriptdir/dependencies/ftp_main.sh" --user="$user" &> /dev/null &
								fi
							else
								echo -e "\e[00;31mERROR: The user $user is running something\e[00m"
								echo "       The script running is: $mypid_script"
								echo "       The transfere is: "$alreadyinprogres""
								echo "       If that is wrong remove you need to remove $lockfile"
								echo "       Wait for it to end, or kill it: kill -9 pidID"
								echo ""
								exit 0
							fi
						else
							# nothing running, start script
							if [[ "$username" == "default" ]]; then
								bash "$scriptdir/dependencies/ftp_main.sh" &> /dev/null &
							else
								bash "$scriptdir/dependencies/ftp_main.sh" --user="$user" &> /dev/null &
							fi
						fi
					fi
				echo
				exit 0
			fi
	;;
	"clear" )
			if [[ -e "$queue_file" ]]; then
				rm "$queue_file"
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Queue removed." "0"
				exit 0
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Queue does not exits." "1"
				exit 1
			fi
	;;	
	"start" )
			if [[ "$username" == "default" ]]; then
				bash "$scriptdir/dependencies/ftp_main.sh" &> /dev/null &
			else
				bash "$scriptdir/dependencies/ftp_main.sh" --user="$user" &> /dev/null &
			fi
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has started." "0"
			exit 0
	;;
	"forget" )
			if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
				#make sure id exists and is present in queue
				echo "Removing id=$id"
				sed "/^"$id"\#/d" -i "$queue_file" #ex -s -c '%s/^[0-9]*//|wq' file.txt if your ex is actually symlinked to the installed vim, then you can use \d and \+
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id=$id removed from queue."	"0"
				exit 0
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id=$id selected/in queue." "1"
				exit 1
			fi
	;;
	"up" )
			if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
				line_info=$(cat "$queue_file" | grep "^$id#")
				line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)			
				previous_line_number=$(($line_number -1))
				if [[ "$line_number" -lt "2" ]]; then
					#if id is the first, keep it there
					message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id, $id, is at top." "0"
					exit 0
				else
					sed "/^"$id"\#/d" -i "$queue_file"
					sed "$previous_line_number i $line_info" -i "$queue_file"
					message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Moved Id=$id, up." "0"
					exit 0
				fi
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id=$id, selected/in queue." "1"
				exit 1
			fi
	;;
	"down" )
			if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
				line_info=$(cat "$queue_file" | grep "^$id#")
				line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)
				next_line_number=$(($line_number +1))
				last_line=$(cat "$queue_file" | grep -ne '' | cut -d':' -f1 | tail -n1 )
				if [[ $next_line_number -eq $last_line ]]; then
					#add id to the end of file
					sed "/^"$id"\#/d" -i "$queue_file"
					echo $line_info >> "$queue_file"
					exit 0
				elif [[ $next_line_number -gt $last_line ]]; then
					#if id is the last, do nothing
					message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Id=$id, is at the buttom." "1"
					exit 0
				else
					#any other cases
					sed "/^"$id"\#/d" -i "$queue_file"
					sed "$next_line_number i $line_info" -i "$queue_file"
					message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Moved Id=$id, down." "0"
					exit 0
				fi
				else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: No Id, $id, selected/in queue." "1"
				exit 1
			fi
	;;
	"online" ) # Perform server test
			source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
			source "$scriptdir/dependencies/ftp_online_test.sh" && online_test
			cleanup session
			if [[ $is_online -eq 0 ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is responding" "0"
				exit 0
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is not responding" "1"
				exit 1			
			fi
	;;
	"freespace" ) # check free space
			source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
			source "$scriptdir/dependencies/ftp_size_management.sh" && ftp_sizemanagement info
			cleanup session
			if [[ $is_online -eq 1 ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Could " "1"
				exit 1
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is responding" "0"
				exit 0
			fi
	;;	
	"test" )
			bash "$scriptdir/dependencies/ftp_main.sh" --test --user="$username" --path="$filepath"
			exit 0
	;;
	* )
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): No options selected." "1"
		exit 1
	;;
esac
