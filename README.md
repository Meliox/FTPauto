# FTPauto

FTPauto is a simple, but highly advanced commandline tool written in Bash for Unix. It relies on [lftp](http://lftp.yar.ru/), but helps to automate simple transfers. So essentially this is a tool to send files from a local server to a remote FTP easily.

If you find this tool helpful, a small donation would be appreciated! Thanks!

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=K8XPMSEBERH3W)

# Features
* Send files easily with lftp
* Highly customizables commandline
* Monitor free space on server
* Progressbar of transfer
* Packing/splitning directory/files into rar-files. Including sfv to verify files at receivers end.
* Multiple user support
* Delay transfer to start at a specific time
* Exec support pre/post transfer
* Sorting (use of regex)
* Exclution of files
* Send push notification to phones etc. with [Pushover](https://pushover.net/)
* Especially powerfull in combination with [FlexGet](http://flexget.com/)

![Pushover](https://pushover.net/assets/pushover-header-eaa79ef56c7041125acbe9fb9290b2fa.png)![FlexGet](http://flexget.com/chrome/site/FlexGet.png)

- - -

## Requirements
You should have User and sudo or root access to use and install, respectively. 

## Installation (Recommended)
To get FTPauto, simple download and run the installer: [download](https://raw.github.com/Meliox/FTPauto/master/install.sh)
The installer will set up the enviroment and will help to install the nessary programs. During the installation you will also be able to set up a user!

```bash
mkdir FTPauto && cd FTPauto
wget https://raw.github.com/Meliox/FTPauto/master/install.sh
bash install.sh install
```

Follow the instructions and now you're ready to use FTPauto! Go to [configuration](https://github.com/Meliox/FTPauto#configuration)

### Get svn
Alternatively, you can get it from Github (This version may contain unfinished features and be ustable).
```bash
git clone https://github.com/Meliox/FTPauto.git
```
Run
```bash 
bash install.sh install
```

### Manually install
If you prefer to do everything manually, read below.

If you want the lastest version of lftp, then compile it from source:
```bash
cd dependencies
sudo apt-get -y install checkinstall libreadline-dev
wget http://lftp.yar.ru/ftp/lftp-4.4.8.tar.gz
tar -xzvf lftp-4.4.8.tar.gz
rm lftp-4.4.8.tar.gz
cd lftp-4.4.8 && ./configuret && make && sudo checkinstall -y
```

Other get the following programs from you repo:
```bash
sudo apt-get -y install rar lftp cksfv subversion automake1.9 fuse-utils libfuse-dev checkinstall libreadline-dev
```

rarfs needs to be compiled:
```bash
cd dependencies/
wget http://downloads.sourceforge.net/project/rarfs/rarfs/0.1.1/rarfs-0.1.1.tar.gz
tar -xzvf rarfs-0.1.1.tar.gz
cd rarfs-0.1.1 && ./configure && make && sudo checkinstall -y
rm dependencies/rarfs-0.1.1.tar.gz
read -p "Which user would you like to run this program at(no spaces)? "
sudo adduser $REPLY fuse
sudo chgrp fuse /dev/fuse
sudo chgrp fuse /dev/fuse
sudo chgrp fuse /bin/fusermount
sudo chmod u+s /bin/fusermount
```

Create directories
```bash
mkdir users/
mkdir run/
```

### Upgrading
Upgrading to new stable version is simple run
```bash
bash install.sh update
```

The same almost goes for git
```bash
git pull
bash install.sh update
```

# Configuration
First thing that need to be done is to create a user and edit the users settings. If you only want one user, you can leave <USERNAME> empty.
```bash
bash ftpauto.sh --add --user=<USERNAME>
```
Editing can be done by
```bash
bash ftpauto.sh --edit --user=<USERNAME>
```
Note: Editing can also be done manually after adding the user!
```bash
nano ~/users/<USERNAME>/config
```
## Settings
The settings should explain themselves:
```bash
#This the the configuration file for ftpautodownload
config_version="1"
#Place the file in /home/ammin/scripts/ftpautodownload-dev/run/'test'/config and load with --user='test' or
# just load it with --config=config_path

#HOWTO: Edit the info between the qoutes "TEST", here the word TEST

#### FTP server Setup - receiver ####
 # If you just want the server to send <ITEM> to your ftp, edit the options below
ftpincomplete="/shares/USB_Storage/temp/" # incomplete directory. Remember trailing slash!
ftpcomplete="/shares/USB_Storage/Download/" # complete directory. Remember trailing slash!
ftpuser="user" # username
ftppass="pass" # password
ftphost="ip" # ipaddres for ftp server
ftpport="port" # ftp port
ssl="false" # Set to true to use ftps else set it to false

#### FTP server Setup - sender ####
ftpuser2="user" # username
ftppass2="pass" # password
ftphost2="ip" # ipaddres for ftp server
ftpport2="port" # ftp port
ssl2="false" # use ftps or not

#### Log settings ###
logrotate="false" #enabled logrotating to move old to log.old
lognumber="50" #how many rls to save before moving to log.old if lograte is set to true otherwise it will remove after rls after X number. 0 for disabled

#### Transfere settings ####

### Filehandling
 # Splitting files if filesize exceed MB. Some FTP servers disconnect after a certain amount of time is there is no
 # aparent activity
split_files="false" # Set to true for enabling filesplitting
rarsplitlimit="1500"
splitsize="100" # How large the rarparts should be in MB
create_sfv="true" # Create sfv for splittet files

### Transfer settings

## General settings
transferetype="upftp or downftp or fxp" # Determine how to transfere file: Either send or receive from ftp or fxp them to another server
parallel="3" # how many simultaneous transferes to download with
queue="true" # if script is executed while something is running, the task is queued
retries="3" # How many times should the transfer be tried, before giving up
retry_download="10" # retry again in minutes after minimum space is reached OR server is offline.
retry_download_max="10" # retry for how many hours, before quitting

## Extra settings
force="false" # Transfere regardless of lockfiles/other transferes
confirm_transfer="false" # Try to confirm transfer
confirm_online="false" # Try to confirm that server is online/writeable before doing anything
exclude_array=( ) # Ignore certain files with name matching, format is ( "word1" "word2" )

## Extra settings
 # To enable FTP space info, ftpsizemanagement has to be set to true
ftpsizemanagement="false" # will confirm enough free space in dir acording to settings
totalmb="14950" # total ftp space
critical="100" # minimum space before aborting transfere

## Processbar settings
 # Processbar shows how the transfer is proceeding, gives eta. etc.
processbar="true" #shows progressbar for transfer
sleeptime="60"  # how often to check transferproces. Time in seconds

## Miscellaneous settings
sort="true" # Sort files into DVD/TV/etc/ or like defined in --cat=CATEGORY. The folders has to exists on server. Changes can be made in /dependencies/sorting.sh
video_file_only="false" # Try to transfer ONLY videofiles, nothing else will be send
exec_post="" #Execute external command upon finish. See --help exec_pre for more info
allow_background="yes" # don't wait for exec to finish. ONLY for exec_post
exec_pre="" #Execute external command before starting. See --help for more info

#### Used for controlscript only ####
autostart="true" # Autostart download when adding something to queue

#### Flexget settings ####
c_flexget="/home/ammin/flexget-download/download.yml"
feed_name="ftpmoviedownload" # feedname for flexget

#### Push notificaions ####
 # Create a user at https://pushover.net/ and enter data below
 # Leave push_user empty if you don't use it
push_token=""
push_user=""
```

# Usage
## Single user
If you didn't add a default user during the installation, then add it
```bash
bash ftpauto.sh --user= --add
```
### Download
Now you can transfer something
```bash
bash ftpauto.sh --path=~/something/
```

## Multiple users
Add users
```bash
bash ftpauto.sh --user=<USERNAME> --add
```
### Download
Now you can transfer something
```bash
bash ftpauto.sh --user=<USERNAME> --path=~/something/
```

## Arguments
Can be shown with
```bash
bash ftpauto.sh --help
```
Here's an overview as well
```bash
== Required ==
      --user=<USER>      | Required at all times in multi user setup, can be omitted in single user setop
== Session manipulation ==
      --pause            | Terminates transfer and leaves queue intact
      --stop             | Terminates transfer and remove queue and current id
      --start            | Begins transfer and let it finish queue
      --online           | Returns if transfer is online or not

== Item manipulation ==
      --list             | Lists all items in queue
      = Required =
       --id=<id>         | Id for <PATH> you want to manipulate. Find them in the queuefile. See --list
      = Options =
       --up              | Move <ID> Up
       --down            | Move <ID> down
       --forget          | Remove <ID> from queue
       --clear           | Remove everything in queue
       --queue=<PATH>    | Sends <PATH> to queue WITHOUT starting script if autostart=false in config. NOTE that --path <ITEM> is required for this to work
       --path=<PATH>     | <PATH> used to transfer now!
       --source=<SOURCE> | Source is used to show how the download has been started. The
                           following is possible:
                           MANDL=manual download(if nothing is used)
                           WEBDL=download from webpage
                           FLXDL=autodownload from flexget
                           other can be used as well...

== User manipulation ==
      --add              | Add user --add=<USER>
      --remove           | Removes all user history
      --purge            | Removes all user history and configs
	  --edit             | Edit <USER> config

== Server ==
      --online           | Checks if server is online and writeable
	  --freespace        | Checks how much free space is available (slow)

	  == Optional ==
      --test             | Shows what transfer is going to happen
      --quiet            | Supresses all output
	  --verbose          | Debugs to console
	  --debug            | Debugs to logfile
	  --force            | Transfer file despite something is running
	  --exec_pre         | Execute commands before download
	  --exec_post        | Execute commands after download
	  --delay            | Delays transfer until X. Has to be in this format "01/01/2010 12:00"
	  --help             | Print help info
```

# 3rd party uses
## FlexGet
First prerequisite is to install Flexget, which can be found here [FlexGet#Install](http://flexget.com/wiki/InstallWizard/Linux/Environment/). Then an appropiate config has to be written as the following example.

This is a serverside configuration!
```yaml
tasks:
 download:
  listdir: [~/TV/, ~/path2/]
  series:
    720p:
      - TVSHOW1
      - TVSHOW2
  exec:
    fail_entries: ye
    allow_background: yes
    auto_escape: yes
    on_output:
      for_accepted: 'sleep 5; bash ~/ftpauto.sh --path="{{location}}/" --user=<USER> --source=FLXDL &'
```

This is a clientside configuration!
```yaml
tasks:
 download:
  rss:
    url: http://....
  series:
    720p:
      - TVSHOW1
      - TVSHOW2
  manipulate:
    SOMETHING IS MISSING HERE
  exec:
    fail_entries: ye
    allow_background: yes
    auto_escape: yes
    on_output:
      for_accepted: 'sleep 5; bash ~/ftpauto.sh --path="{{location}}/" --user=<USER> --source=FLXDL &'
```

Having written the config properly i.e. without it failing, i.e. pass
```bash
bin/flexget --check
```
and it may be added to crontab. Do this by
```bash
crontab -e
```
and add this entry
```bash
*/5 * * * * /home/ammin/flexget-download/bin/flexget --cron
```
, where 5 minutes is the interval checking for new files.

NOTE: Flexget only handle one user PER show, so if several users see the same you need to add addtional configs to crontab like
```bash
*/5* * * * /home/ammin/flexget-rss/bin/flexget -c ~/flexget/config2.yml --cron\
```
More info on FlexGet and how it work is not going to be explained as it is done so very nicely on their homepage, [FlexGet#Configuration]/http://flexget.com/wiki/Configuration/)
