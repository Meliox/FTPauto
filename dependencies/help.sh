#!/bin/bash
function write_config {
#write show_example to config
	echo -n "Preparing config ..."
	if [[ -z "$username" ]]; then
		user=default
	fi
	echo -e "\e[00;32m [OK]\e[00m"
	local config="$scriptdir/users/$username/config"
	if [[ ! -d "$scriptdir/users" ]]; then
		mkdir "$scriptdir/users"
	fi
	if [[ ! -d "$scriptdir/users/$username" ]]; then
		mkdir "$scriptdir/users/$username"
	fi
	if [[ -f "$config" ]]; then
		read -p " Config already exits($config), do you want to overwrite(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			show_example > "$config"
			echo "Config written to \"$config\""
		fi
	else
		show_example > "$config"
		echo "Config written to \"$config\""
	fi
}

function show_help {
echo -e "
\033[1mHomepage\033[0m
\e[04;34mhttps://bitbucket.org/teamsilent/ftpautodownload/\e[00m

\033[1mDescription\033[0m
  FTPauto is a bash commandline tool to send files from a local server to\n  a remote easily. Numerous options may be specified such a checking free space for \n  transfering, multiple user support, delay of transfer and category support. It is\n  especially powerfull in combination with Flexget

  For more information read the README or see homepage.
  
IMPORTANT: Default is always used if --user isn't used!

\033[1mOptions\033[0m
== Required ==
	--user=<USER>      | Required at all times in multi user setup, can be omitted in single user setop
== Session manipulation ==
	--pause            | Terminates transfer and leaves queue intact
	--start            | Begins transfer from queue and let it finish queue. Only to be used for sessions!
	--stop             | Terminates transfer and remove queue and current id

== Item manipulation ==
	--list             | Lists all items in queue
	= Required =
	  --id=<id>         | Id for <PATH> you want to manipulate. Find them in the queuefile. See --list
	= Options =
	  --clear           | Remove everything in queue
	  --down            | Move <ID> down
	  --forget          | Remove <ID> from queue
	  --path=<PATH>     | <PATH> used to transfer now!
	  --queue           | Sends <PATH> to queue WITHOUT starting script if autostart=false in config.
						   NOTE that --path <ITEM> is required for this to work.
						   Might also be used to start transfer in background if autostart=true	   
	  --source=<SOURCE> | Source is used to show how the download has been started. The
						   following is possible:
						   MANDL=manual download(if nothing is used)
						   WEBDL=download from webpage
						   FLXDL=autodownload from flexget
						   other can be used as well...
	  --up              | Move <ID> Up

== User manipulation ==
	--add              | Add user --add=<USER>
	--edit             | Edit <USER> config
	--purge            | Removes all user history and configs
	--remove           | Removes all user history

== Server ==
	--freespace        | Checks how much free space is available (slow if on remote server)
	--online           | Checks if server is online and writeable

== Optional ==
	--bg               | Transfer is done in background
	--debug            | Debugs to logfile
	--delay            | Delays transfer until X. Has to be in this format "01/01/2010 12:00" (Month/Day/Year 24h-time)
	--exec_post        | Execute commands after download
	--exec_pre         | Execute commands before download
	--force            | Transfer file despite something is running
	--help             | Print help info
	--progress         | While transfering, this will print out progress if enabled in config	
	--quiet            | Supresses all output
	--test             | Shows what transfer is going to happen
	--verbose          | Debugs to console
  "
}

function show_example {
#shows an example for configuration
	echo
	echo	"#This the the configuration file for ftpautodownload"
	echo	"config_version=\"2\""
	echo	"#Place the file in $scriptdir/run/'$username'/config and load with --user='$username' or"
	echo	"# just load it with --config=config_path"
	echo
	echo	"#HOWTO: Edit the info between the qoutes \"TEST\", here the word TEST"
	echo
	echo	"#### FTP server Setup ####"
	echo	" # If you just want the server to send <ITEM> to your ftp, edit the options below"
	echo	"transferetype=\"upftp or downftp or fxp\" # Determine how to transfere file: Either send or receive from ftp or fxp them to another server"	
	echo	""
	echo	" # These directories are where you want to download/send the item" 
	echo	"ftpincomplete=\"/shares/USB_Storage/temp/\" # incomplete directory. Remember trailing slash!"
	echo	"ftpcomplete=\"/shares/USB_Storage/Download/\" # complete directory. Remember trailing slash!"
	echo	""
	echo	"#### DOWN/UP MODE ####"
	echo	" # If you just want to send/receive items, change these"
	echo	"ftpuser=\"user\" # username"
	echo	"ftppass=\"pass\" # password"
	echo	"ftphost=\"ip\" # ipaddres for ftp server"
	echo	"ftpport=\"port\" # ftp port"
	echo	"ssl=\"false\" # Set to true to use ftps else set it to false"
	echo	""
	echo	"#### FXP MODE ####"
	echo	" # If you just want to send/receive items from one server to another, change these also!"
	echo	"ftpuser2=\"user\" # username"
	echo	"ftppass2=\"pass\" # password"
	echo	"ftphost2=\"ip\" # ipaddres for ftp server"
	echo	"ftpport2=\"port\" # ftp port"
	echo	"ssl2=\"false\" # use ftps or not"
	echo
	echo	"#### Log settings ###"
	echo	"logrotate=\"false\" #enabled logrotating to move old to log.old"
	echo	"lognumber=\"50\" #how many rls to save before moving to log.old if lograte is set to true otherwise it will remove after rls after X number. 0 for disabled"
	echo
	echo	"#### Transfere settings ####"
	echo
	echo	"### Filehandling"
	echo	" # Splitting files if filesize exceed MB. Some FTP servers disconnect after a certain amount of time is there is no"
	echo	" # aparent activity"
	echo	"split_files=\"false\" # Set to true for enabling filesplitting"	
	echo 	"rarsplitlimit=\"1500\""
	echo	"splitsize=\"100\" # How large the rarparts should be in MB"
	echo	"create_sfv=\"true\" # Create sfv for splittet files"
	echo	""
	echo	"### Transfer settings"
	echo
	echo	"## General settings"
	echo	"parallel=\"3\" # how many simultaneous transferes to download with"
	echo	"queue=\"true\" # if script is executed while something is running, the task is queued"
	echo	"retries=\"3\" # How many times should the transfer be tried, before giving up"
	echo 	"retry_download=\"10\" # retry again in minutes after minimum space is reached OR server is offline."
	echo	"retry_download_max=\"10\" # retry for how many hours, before quitting"	
	echo
	echo	"## Extra settings"
	echo	"force=\"false\" # Transfere regardless of lockfiles/other transferes"
	echo	"confirm_transfer=\"false\" # Try to confirm transfer"
	echo	"confirm_online=\"false\" # Try to confirm that server is online/writeable before doing anything"
	echo	"exclude_array=( ) # Ignore certain files with name matching, format is ( \"word1\" \"word2\" )"
	echo
	echo	"## Extra settings"
	echo	" # To enable FTP space info, ftpsizemanagement has to be set to true"
	echo	"ftpsizemanagement=\"false\" # will confirm enough free space in dir acording to settings"
	echo	"totalmb=\"14950\" # total ftp space"
	echo	"critical=\"100\" # minimum space before aborting transfere"	
	echo
	echo	"## Processbar settings"
	echo	" # Processbar shows how the transfer is proceeding, gives eta. etc."
	echo 	"processbar=\"true\" #shows progressbar for transfer"
	echo	"sleeptime=\"60\"  # how often to check transferproces. Time in seconds"
	echo
	echo	"## Miscellaneous settings"
	echo 	"sort=\"true\" # Sort files into DVD/TV/etc/ or like defined in --cat=CATEGORY. The folders has to exists on server. Changes can be made in /dependencies/sorting.sh"
	echo    "video_file_only=\"false\" # Try to transfer ONLY videofiles, nothing else will be send"	
	echo	"exec_post=\"\" #Execute external command upon finish. See --help exec_pre for more info"
	echo	"allow_background=\"yes\" # don't wait for exec to finish. ONLY for exec_post"
	echo	"exec_pre=\"\" #Execute external command before starting. See --help for more info"
	echo
	echo	"#### Used for controlscript only ####"
	echo	"autostart=\"true\" # Autostart download when adding something to queue"
	echo
	echo	"#### Push notificaions ####"
	echo	" # Create a user at https://pushover.net/ and enter data below"
	echo	" # Leave push_user empty if you don't use it"
	echo	"push_token=\"\""
	echo	"push_user=\"\""
}

function create_log_file {
	if [ ! -e "$logfile" ]; then
		echo "INFO: First time used - logfile is created"
		echo "***************************	FTPauto - $s_version" >> $logfile
		echo "***************************	STATS: 0MB in 0 transfers in 00d:00h:00m:00s" >> $logfile
		if [[ $ftpsizemanagement == "true" ]]; then
			echo "***************************	FTP INFO: 0/"$totalmb"MB (Free "$freemb"MB)" >> $logfile
		else
			echo "***************************	FTP INFO: not used yet" >> $logfile
		fi
		echo "***************************	LASTDL: nothing" >> $logfile
		echo "***************************	" >> $logfile
		echo "**********************************************************************************************************************************" >> $logfile
		echo "" >> $logfile
		else
			echo "INFO: Logfile: $logfile"
			# clean log file
			echo "***************************	FTP INFO:" >> $logfile
	fi
}