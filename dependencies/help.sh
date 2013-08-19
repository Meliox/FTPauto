#!/bin/bash
function write_config {
#write show_example to config
	echo "INFO: Preparing config"
	if [[ -n "$user" ]]; then
		echo "INFO: Writing config for user=$user"
		local config="$scriptdir/users/$user/config"
		if [[ ! -d "$scriptdir/users" ]]; then
			mkdir "$scriptdir/users"
		fi
		if [[ ! -d "$scriptdir/users/$user" ]]; then
			mkdir "$scriptdir/users/$user"
		fi
		if [[ -f "$config" ]]; then
			echo ""
			read -p "Config already exits($config), do you want to overwrite? (y/n)?  :  "
			if [[ "$REPLY" == "y" ]]; then
				show_example > "$config"
				echo "Config written to \"$config\""
			fi
		else
			show_example > "$config"
			echo "Config written to \"$config\""
		fi
	else
		echo "INFO: Writing config for default"
		local config="$scriptdir/users/default"
		if [[ -f "$config" ]]; then
			echo ""
			read -p "Config already exits($config), do you want to overwrite? (y/n)?  :  "
			if [[ "$REPLY" == "y" ]]; then
				show_example > "$config"
				echo "Config written to \"$config\""
			fi
		else
			show_example > "$config"
			echo "Config written to \"$config\""
		fi
	fi
	echo
}

function show_help {
#displays help info
	echo -e "     Homepage: \e[04;34mhttps://bitbucket.org/teamsilent/ftpautodownload/\e[00m"
	echo
	echo -e "\e[1;30m  What is this...\e[00m"
	echo -e "  FTP AUTODOWNLOAD script is a simple commandline tool to send files from a local server to\n  a remote easily. Numerous options may be specified such a checking free space for \n  transfering, multiple user support, delay of transfer and category support. It is\n  especially powerfull in combination with \e[00;33mFlexget\e[00m which can be found at \e[04;34mhttp://flexget.com/\e[00m"
	echo ""
	echo -e "\e[1;30m  Arguments allowed are\e[00m"
	echo "     --help or -h displays help info"
	echo "     --quiet supresses all output"
	echo "     --verbose or -v displays debug info"
	echo "     --path or -p ~/home/ or path=~/home"
	echo "     --feed flexgetfeedname or --feed=name"
	echo "     --user or -u username or --user=name"
	echo "     --force or -f ignores lockfile"
	echo "     --online returns if server is online or not"
	echo "     --freespace returns how much freespace is available on server. Requires ftpsizemanagement=\"true\" in config"
	echo "     --category=CAT save to custom category in a subdirectory in ftpcomplete directory set below"
	echo "     --delay=\"01/01/2010 12:00\" has to be in this format!"
	echo "     --example shows configuration example"
	echo "     --test try the script without actual transfer"
	echo "     --exec_post see exec_pre further explanation"
	echo "       allow_background=\"yes\" might be used in config so that ftpautodownloadscript will not wait for it to finish"	
	echo "     --exec_pre execute an external command. Be sure to use '' to qoute the command."
	echo "       Please note that the command has to be written correctly in order to be carried out properly"
	echo "       The following can be used:"
	echo "         "'$user'": States to user being used"
	echo "         "'$size'": States to total transfer size"
	echo "         "'$orig_name'": States the transfername"
	echo "         "'$source'": States the source used for the transfer"
	echo "         "'$ftpcomplete'": States the complete directory"
	echo "         "'$ftpincomplete'": States the incomplete directory"
	echo -e "     --source INFO: Source is used to show how the download has been started. The\n       following is possible:\n         MANDL=manual download(if nothing is used)\n         MANDLQ=manual download from queue\n         WEBDL=download from webpage\n         WEBDLQ=download queue from webpage\n         FLXDL=autodownload from flexget\n         FLXDL=autodownload from flexget\n         FLXDLQ=autodownload from flexget queue"
	echo
	echo -e "\e[00;31m     Remember quotes for all possible cases!\e[00m"
	echo ""
	echo ""
	echo -e "\e[1;30m  Examples of use\e[00m"
	echo "      Example of single user support"
	echo "      bash ftpautodownloadscript.sh --path="~/path/" --delay=\"01/01/2010 12:00\" --cat=\"TV\""
	echo ""
	echo "      Example of multiuser support"
	echo -e "      bash ftpautodownloadscript.sh --user=\"admin\" --path="~/path/"\n      --delay=\"01/01/2010 12:00\" --cat=\"TV\""
	echo -e "       Almost the same af single user, but the config setup is different as the\n       config has to be here ~/users/USERNAME/config. The whole transprocess, lockfiles etc.\n       are to be found in ~/run for all users"
	echo ""
	echo -e "      Using \e[00;33mFlexget\e[00m"
	echo -e "      First prerequisite is to install Flexget, which can be found here:\n      \e[04;34mhttp://flexget.com/wiki/InstallWizard/Linux/Environment/\e[00m\n      Then an appropiate config has to be written as the following example. How Flexget\n      config works is not going to be explained as it is done so very nicely on their\n      homepage, \e[04;34mhttp://flexget.com/wiki/Configuration\e[00m"
	echo ""
	echo "         Flexget config:"
	echo "         -------------------------"
	echo "            tasks:"
	echo "              USER:"
	echo "                listdir: [~/TV/, ~/path2/]"
	echo "                series:"
	echo "                  720p:"
	echo "                    - TVSHOW1"
	echo "                    - TVSHOW2"
	echo "                exec:"
	echo "                  fail_entries: yes"
	echo "                  allow_background: yes"
	echo "                  auto_escape: yes"
	echo "                  on_output:"
	echo -e "                    for_accepted: 'sleep 5; bash ~/ftpautodownloadscript.sh \n         --path="{{location}}/" --user=USER --source=FLXDL &'"
	echo "         -------------------------"
	echo -e "         Having written the config properly i.e. without it failing\n         \"bin/flexget --check\", it may be added to crontab. Do this by crontab -e and write\n         \"*/5 * * * * /home/ammin/flexget-download/bin/flexget --cron\". 5, minutes, is\n         the interval checking for new files. \e[00;33mINFO\e[00m: Flexget only handle one user PER show,\n         so if several users see the same you need to add addtional configs to crontab like\n         \"*/5* * * * /home/ammin/flexget-rss/bin/flexget -c ~/flexget/config2.yml --cron\""
	echo
	exit 0
}

function show_example {
#shows an example for configuration
	echo
	echo	"#This the the configuration file for ftpautodownload"
	echo	"config_version=\"1\""
	echo	"#Place the file in $scriptdir/run/'$username'/config and load with --user='$username' or"
	echo	"# just load it with --config=config_path"
	echo
	echo	"#HOWTO: Edit the info between the qoutes \"TEST\", here the word TEST"
	echo
	echo	"#### FTP server Setup - receiver ####"
	echo	" # If you just want the server to send <ITEM> to your ftp, edit the options below"
	echo	"ftpincomplete=\"/shares/USB_Storage/temp/\" # incomplete directory. Remember trailing slash!"
	echo	"ftpcomplete=\"/shares/USB_Storage/Download/\" # complete directory. Remember trailing slash!"
	echo	"ftpuser=\"user\" # username"
	echo	"ftppass=\"pass\" # password"
	echo	"ftphost=\"ip\" # ipaddres for ftp server"
	echo	"ftpport=\"port\" # ftp port"
	echo	"ssl=\"false\" # Set to true to use ftps else set it to false"
	echo
	echo	"#### FTP server Setup - sender ####"
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
	echo	"transferetype=\"upftp or downftp or fxp\" # Determine how to transfere file: Either send or receive from ftp or fxp them to another server"
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
	echo	"#### Flexget settings ####"
	echo    "c_flexget=\"/home/ammin/flexget-download/download.yml\""
	echo    "feed_name=\"ftpmoviedownload\" # feedname for flexget"
	echo
	echo	"#### Push notificaions ####"
	echo	" # Create a user at https://pushover.net/ and enter data below"
	echo	" # Leave push_user empty if you don't use it"
	echo	"push_token=\"\""
	echo	"push_user=\"\""
}