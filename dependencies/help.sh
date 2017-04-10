#!/bin/bash
function write_config {
	local config
	# write show_example to config
	echo -n "Preparing config ..."
	if [[ -z "$username" ]]; then
		user=default
	fi
	config="$scriptdir/users/$username/config"
	mkdir -p "$scriptdir/users/$username"
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
  FTPauto is a bash command line tool to send files from a local server to\n  a remote easily. Numerous options may be specified such a checking free space for \n  transferring, multiple user support, delay of transfer and category support. It is\n  especially powerful in combination with Flexget

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
	  --sort            | Sorts transfer into passed directory. Usage --sort=somedir/somedir2/
                               This will overwrite automatic sorting.
                               --sort=nosort transfers into ftpcomplete directory if sorting is enabled

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
	--progress         | While transferring, this will print out progress if enabled in config
	--quiet            | Suppresses all output
	--test             | Shows what transfer is going to happen
	--verbose          | Debugs to console
  "
}

function show_example {
#shows an example for configuration
	echo
	echo	"#This the the configuration file for FTPauto"
	echo	"config_version=\"6\""
	echo	"#Place the file in $scriptdir/run/'$username'/config and load with --user='$username'"
	echo
	echo	"#HOWTO: Edit the info between the qoutes \"TEST\", here the word TEST"
	echo
	echo	"#### FTP server Setup ####"
	echo	" # If you just want the server to send <ITEM> to your ftp, edit the options below"
	echo	"transferetype=\"(upftp|downftp|fxp)\" # Determine how to transfer file: Either send or receive from ftp or fxp them to another server"	
	echo	""
	echo	" # These directories are where you want to download/send the item. REMEMBER TRAILING SLASH"
	echo	"ftpincomplete=\"~/somedirectory/incomplete/\" # incomplete directory. Leave empty if no incomplete directory should be used"
	echo	"ftpcomplete=\"~/somedirectory/complete/\" # complete directory."
	echo	""
	echo	"#### DOWN/UP MODE ####"
	echo	" # If you just want to send/receive items, change these"
	echo	"ftpuser1=\"user\" # username"
	echo	"ftppass1=\"pass\" # password"
	echo	"ftphost1=\"ip\" # ip address for ftp server"
	echo	"ftpport1=\"port\" # ftp port"
	echo	"ftpssl1=\"false\" # Set to true to use ftps else set it to false"
	echo	"ftpcustom1=\"\" # Enter settings separated by ';', eg. set cache:expire 1;set cache:size 2"
	echo	""
	echo	"#### FXP MODE ####"
	echo	" # If you just want to send/receive items from one server to another, change these also! In FXP mode, ftphost1 is source and ftphost2 receiver"
	echo	"ftpuser2=\"user\" # username"
	echo	"ftppass2=\"pass\" # password"
	echo	"ftphost2=\"ip\" # ip address for ftp server"
	echo	"ftpport2=\"port\" # ftp port"
	echo	"ftpssl2=\"false\" # use ftps or not"
	echo	"ftpcustom2=\"\" # Enter settings separated by ';', eg. set cache:expire 1; set cache:size 2"
	echo
	echo	"#### Log settings ###"
	echo	"logrotate=\"false\" #enabled logrotating to move old to log.old"
	echo	"lognumber=\"50\" #how many transfers to save in log before moving to log.old. 0 for disabled"
	echo
	echo	"#### Transfer settings ####"
	echo
	echo	"### Filehandling"
	echo	" # Splitting files if filesize exceed MB. Some FTP servers disconnect after a certain amount of time is there is no"
	echo	" # activity. These settings only work if the server handling the script also sends the files, i.e. in upftp and upfxp mode!"
	echo    "send_option=\"(video|split|default)\" # Can be configured to send only videofile, split files according to settings or simply transfer the , default. If videofile or sizelimit are not met, then the files will be transfered as default - without any modifications."
	echo	"splitsize=\"100\" # How large the rarparts should be in MB"
	echo	"create_sfv=\"false\" # Create sfv for rarfiles"
	echo	""
	echo	"### Transfer settings"
	echo
	echo	"## General settings"
	echo	"parallel=\"3\" # how many simultaneous transfers to download with"
	echo	"continue_queue=\"true\" # Script will continue downloading if something is queued"
	echo	"retries=\"3\" # How many times should the transfer be tried, before giving up"
	echo 	"retry_download=\"10\" # retry again in minutes after minimum space is reached OR server is offline."
	echo	"retry_download_max=\"30\" # retry for how many minites, before quitting. Recommended 30 mins. For each try 3 tries to establish connection with furthermore be tried"
	echo
	echo	"## Extra settings"
	echo	"force=\"false\" # Transfer regardless of lockfiles/other transfers"
	echo	"confirm_transfer=\"false\" # Try to confirm transfer"
	echo	"confirm_online=\"false\" # Try to confirm that server is online/writeable before doing anything"
	echo	"exclude_array=( ) # Ignore certain files with name matching, format is ( \"word1\" \"word2\" )"
	echo
	echo	"## Extra settings"
	echo	" # To enable FTP space info, ftpsizemanagement has to be set to true"
	echo	"ftpsizemanagement=\"false\" # will confirm enough free space in dir according to settings"
	echo	"totalmb=\"14950\" # total ftp space in mb"
	echo	"critical=\"100\" # minimum space before aborting transfer in mb"
	echo
	echo	"## Processbar settings"
	echo	" # Processbar shows how the transfer is proceeding, gives eta. etc."
	echo	"sleeptime=\"60\"  # how often to provide progress information. Time in seconds"
	echo
	echo	"## Miscellaneous settings"
	echo	"exec_post=\"\" #Execute external command upon finish. See --help exec_pre for more info"
	echo	"allow_background=\"false\" # don't wait for exec to finish. ONLY for exec_post"
	echo	"exec_pre=\"\" #Execute external command before starting. See --help for more info"
	echo 	"sort=\"false\" # Sort files into DVD/TV/etc/ or like defined in --sort=DIRECTORY. Changes can be made in the file /dependencies/sorting.sh"
	echo
	echo	"#### Push notifications ####"
	echo	" # Create a user at https://pushover.net/ and enter details below"
	echo	" # Leave push_user empty if you don't use it"
	echo	"push_token=\"\""
	echo	"push_user=\"\""
}

function create_log_file {
	if [[ ! -e "$logfile" ]]; then
		echo "INFO: First time usage. Logfile is created"
		echo "***************************	FTPauto - $s_version" >> "$logfile"
		echo "***************************	STATS: 0MB in 0 transfers in 00d:00h:00m:00s" >> "$logfile"
		if [[ $ftpsizemanagement == true ]]; then
			echo "***************************	FTP INFO: 0/${totalmb}MB (Free ${freemb}MB)" >> "$logfile"
		else
			echo "***************************	FTP INFO: (not used yet)" >> "$logfile"
		fi
		echo "***************************	LASTDL: nothing" >> "$logfile"
		echo "***************************	" >> "$logfile"
		echo "**********************************************************************************************************************************" >> "$logfile"
		echo "" >> "$logfile"
		else
			echo "INFO: Logfile: "$logfile""
			# clean log file
			echo "***************************	FTP INFO:" >> "$logfile"
	fi
}
