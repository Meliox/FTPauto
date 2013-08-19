#!/bin/bash
s_version="0.87"
verbose=0
script="$(readlink -f $0)"
scriptdir=$(dirname $script)
scriptdir=${scriptdir%/utils}

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
	echo "  The purpose of this controlscript is the control ftpautodownloadscript i.e. do the"
	echo "   following stuff instead easily. This is meant as an addon, but is not required for"
	echo "   the use of ftpautodownloadscript"
	echo ""
	echo "  The following arguments are available"
	echo "     --pause terminates ftpautodownloadscript and leaves queue intact"
	echo "     --stop terminates ftpautodownloadscript and remove queue and current id"
	echo "     --start executes ftpautodownloadscript and let it finish queue"
	echo "     --up move Id UP"
	echo "     --down move Id down"
	echo "     --online returns if server is online or not"
	echo "     --queue sends <ITEM> to queue WITHOUT starting script. NOTE that --path <ITEM> is required for this to work"
	echo "     --path or -p ~/home/ or path=~/home. Only used for --queue"
	echo "     --remove remove Id from queue"
	echo "     --clear remove everything in queue"
	echo "     --id=<id> id for <ITEM> you want to manipulate. find them in the queuefile "
	echo "     --quiet supresses all output"
	echo "     --source <SOURCE>: Source is used to show how the download has been started. The\n       following is possible:\n         MANDL=manual download(if nothing is used)\n         MANDLQ=manual download from queue\n         WEBDL=download from webpage\n         WEBDLQ=download queue from webpage\n         FLXDL=autodownload from flexget\n         FLXDL=autodownload from flexget\n         FLXDLQ=autodownload from flexget queue"
	echo ""
	echo "  IMPORTANT: Controling the following"
	echo "    Default is always used if none of the following is set"
	echo "    --user=<USER> control the USER choosen"
	echo
}

#Load dependencies
source "$scriptdir/dependencies/setup.sh"

################################################### CODE BELOW #######################################################

echo
echo -e "\e[00;34mControlscript for ftpautodownloadscript - $s_version\e[00m"
echo

if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified\e[00m"; echo "See --help for more information"; echo ""; exit 0; fi
while :
do
	case "$1" in
		--help | -h ) show_help; exit 1;;
		--verbose | -v) verbose=1; shift;;
		--pause ) option=pause; shift;;
		--stop ) option=stop; shift;;
		--online ) option=online; shift;;
		--quiet ) quiet=true; shift;;
		--start ) option=start; shift;;
		--remove ) option=remove; shift;;
		--queue ) option=queue; shift;;
		--clear ) option="clear"; shift;;
		--source=* ) source=${1#--source=}; if [[ -z $source ]]; then show_help; exit 1; fi; shift;;
		--source | -s ) if (($# > 1 )); then source=$2; if [[ -z $source ]]; then show_help; exit 1; fi; else echo "Invalid option for argument '$@'"; show_help; exit 1; fi; shift 2;;		
		--up ) option=up; shift;;
		--down ) option=down; shift;;
		--id ) if (($# > 1 )); then id=$2; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--id=* ) id=${1#--id=}; shift;;
		--user ) if (($# > 1 )); then user=$2; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--user=* ) user=${1#--user=}; shift;;
		--path | -p ) if (($# > 1 )); then filepath=$2; else echo -e "\e[00;31mInvalid option for argument '$@'\e[00m"; show_help; exit 1; fi; shift 2;;
		--path=* ) filepath=${1#--path=}; shift;;
		-* ) echo -e "\e[00;31mInvalid option: $@\e[00m"; echo "Try viewing --help"; exit 0;;
		* ) break ;;
		--) shift; break;;
	esac
done
if [[ $quiet ]]; then
	#silent
	exec > /dev/null 2>&1
elif [[ ! $quiet ]] && [[ $verbose == 1 ]]; then
	#verbose
	exec 2>> $scriptdir/run/$user.control.debug
	set -x
elif [[ $quiet ]] && [[ $verbose == 1 ]]; then
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
else
	if [[ -z "$user" ]]; then
		echo -e "\e[00;31mERROR: No config found for default\e[00m"
	elif [[ -n "$user" ]]; then
		echo -e "\e[00;31mERROR: No config found for user=$user\e[00m"
	fi
	echo -e "\e[00;31mYou may want to have a look on help, --help\e[00m"
	exit 1
fi
#load paths to everything
setup

case "$option" in
	"pause" )
			if [[ -f "$lockfile" ]]; then
				# clean up everything
				cleanup stop
				cleanup session
				cleanup end
				message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has been terminated." "0"
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
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Error, lockfile couldn't be found. Nothing could be done!" "1"
				exit 1
			fi
	;;
	"queue" )
			if [[ ! -d "$filepath" ]] || [[ ! -f "$filepath" ]] && [[ -z $(find "$filepath" -type f) ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): ERROR: Option --path is required with existing path and has to contain file(s).\n See --help for more info!!" "1"
				exit 1			
			else
				get_size "$filepath" "exclude_array[@]" &> /dev/null
				if [[ -e "$queue_file" ]]; then
					if [[ -n $(cat $queue_file | grep $(basename $filepath)) ]]; then
						echo "INFO: Item already exists. Doing nothing."
						exit 1
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
									bash "$scriptdir/ftpautodownloadscript.sh" &> /dev/null &
								else
									bash "$scriptdir/ftpautodownloadscript.sh" --user="$user" &> /dev/null &
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
								bash "$scriptdir/ftpautodownloadscript.sh" &> /dev/null &
							else
								bash "$scriptdir/ftpautodownloadscript.sh" --user="$user" &> /dev/null &
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
				bash "$scriptdir/ftpautodownloadscript.sh" &> /dev/null &
			elif [[ "$username" == "config" ]]; then
				bash "$scriptdir/ftpautodownloadscript.sh" --config="$config" &> /dev/null &
			else
				bash "$scriptdir/ftpautodownloadscript.sh" --user="$user" &> /dev/null &
			fi
			message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Session has started." "0"
			exit 0
	;;
	"remove" )
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
	"online" )
			if [[ "$username" == "default" ]]; then
				bash "$scriptdir/ftpautodownloadscript.sh" --online &> /dev/null
			elif [[ "$username" == "config" ]]; then
				bash "$scriptdir/ftpautodownloadscript.sh" --config="$config" --online &> /dev/null
			else
				bash "$scriptdir/ftpautodownloadscript.sh" --user="$user" --online &> /dev/null
			fi
			if [[ $? -eq 1 ]]; then
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is not responding" "1"
				exit 1
			else
				message "$(date '+%d/%m/%y-%a-%H:%M:%S'): $option: Server is responding" "0"
				exit 0
			fi
	;;
	* )
		message "INFO: $(date '+%d/%m/%y-%a-%H:%M:%S'): No options selected." "1"
		exit 1
	;;
esac
