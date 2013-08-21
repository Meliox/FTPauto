#!/bin/bash
version="0.4"

### code below
function setup {
	# programs
	lftp=$(which lftp)
	rarfs=$(which rarfs)
	# paths 
	queue_file="$scriptdir/run/$username.queue"
	lockfile="$scriptdir/run/$username.lck"
	logfile="$scriptdir/users/$username/log"
	oldlogfile="$scriptdir/users/$username/log.old"
	ftptransfere_file="$scriptdir/run/$username.ftptransfere"
	ftptransfere_processbar="$scriptdir/run/$username.ftpprocessbar"
	ftplogin_file="$scriptdir/run/$username.ftplogin"
	ftpfreespace_file="$scriptdir/run/$username.ftpfreespace"
	ftpalive_file="$scriptdir/run/$username.ftpalive"
	ftpcheck_testfile="$scriptdir/run/$username.testfile"
	ftpcheck_file="$scriptdir/run/$username.ftpcheck"
	proccess_bar_file="$scriptdir/run/$username.transfered.info"
	ftp_size_file="$scriptdir/run/$username.ftpsize.info"
	log_control="$scriptdir/run/$username.controllog"
	scriptdebugfile="$scriptdir/run/$username.debug"
	lftpdebug="$scriptdir/run/$username.lftpdebug"
}

function get_size {
	#called with $filepath $exclude_array[@]
	local dir="$1"
	local var=("${!2}")
	directorysize=$(du -bs "$dir" | awk '{print $1}')
	size=$(echo "scale=2; "$directorysize" / (1024*1024)" | bc)	
	echo "INFO: Size to transfere: "$size"MB"
	if [[ -n "$var" ]]; then
		local exp=()
		for i in "${var[@]}"; do
			exp+=(-iname "$i")
		done
		exp="( ${exp[@]} -prune -o -type f )" #
		size=$(find "$dir" $exp -type f -printf '%s\n' | awk -F ":" '{sum+=$NF} END { printf ("%0.0f\n", sum)}')
		size=$(echo "scale=2; "$size" / (1024*1024)" | bc)
		echo "INFO: Updated size to transfere(filter used): "$size"MB"
	fi
}

function cleanup {
	case "$1" in
	"die" ) #used when script stops on user input
	        echo "*** Ouch! Exiting ***"
			# remove pids and lockfile
	        if [[ -n "$pid_transfer" ]]; then kill -9 $pid_transfer &> /dev/null; fi
        	if [[ -n "$pid_f_process" ]]; then kill -9 $pid_f_process &> /dev/null; fi
		if [[ -f "$lockfile" ]] && [[ -n $(sed -n '4p' $lockfile) ]]; then kill -9 $(sed -n '4p' $lockfile) &> /dev/null; fi
		if [[ -f "$queue_file" ]]; then rm "$queue_file"; fi;
		if [[ -f "$lockfile" ]]; then rm "$lockfile"; fi;
		#remove all files created
		cleanup session
		sed "5s#.*#*************************** Transfer: Aborted #" -i $logfile
	        exit 1;;
	"session" ) #use to end transfer
		if [[ $test_mode == "true" ]]; then
			read -sn 1 -p "Press ANY buttom to continue cleanup..."
		fi
		if [[ -f "$ftplogin_file" ]]; then rm "$ftplogin_file"; fi
		if [[ $mount_in_use == "true" ]]; then
			mountsystem umount
			unset mount_in_use tempmountset
		fi
		if [[ -d "$tempdir" ]]; then rm -r "$tempdir"; fi;
		if [[ -f "$ftptransfere_file" ]]; then rm "$ftptransfere_file"; fi
		if [[ -f "$ftpfreespace_file" ]]; then rm "$ftpfreespace_file"; fi
		if [[ -f "$proccess_bar_file" ]]; then rm "$proccess_bar_file"; fi
		if [[ -f "$ftpalive_file" ]]; then rm "$ftpalive_file"; fi
		if [[ -f "$ftpcheck_file" ]]; then rm "$ftpcheck_file"; fi
		if [[ -f "$ftpcheck_testfile" ]]; then rm "$ftpcheck_testfile"; fi
		if [[ -f "$ftptransfere_processbar" ]]; then rm "$ftptransfere_processbar"; fi
		echo "INFO: Cleanup done"
	;;
	"end" ) #use to end script
		if [[ -f "$lockfile" ]]; then rm "$lockfile"; fi;
		sed "5s#.*#***************************	#" -i $logfile
		echo -e "\e[00;32mExiting succesfully...\e[00m"
		echo ""
	;;
	"stop" ) #use to terminate all pids used
		if [[ -n $(sed -n '1p' $lockfile) ]]; then kill -9 $(sed -n '1p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '2p' $lockfile) ]]; then kill -9 $(sed -n '2p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '3p' $lockfile) ]]; then kill -9 $(sed -n '3p' $lockfile) &> /dev/null; fi
		if [[ -n $(sed -n '4p' $lockfile) ]]; then kill -9 $(sed -n '4p' $lockfile) &> /dev/null; fi
	;;
esac
}