# FTPauto

FTPauto is a simple, but highly advanced command line tool written in #Bash for Unix. It relies on [lftp](http://lftp.yar.ru/), but helps to automate simple transfers. So essentially this is a tool to send files from a local server to a remote FTP easily.

If you find this tool helpful, a small donation would be appreciated! Thanks!

[![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=K8XPMSEBERH3W)

# Features
* Send files easily with lftp
* Highly customizable command line
* Monitor free space at end-server
* Progressbar of transfer
* Packing/splitting directory/files into rar-files. Including sfv to verify files at end-server.
* Multiple users support
* Delay transfer to start at a specific time
* Exec support pre/post transfer
* Sorting (use of regex)
* Exclution of files
* Send push notification to phones etc. with [Pushover](https://pushover.net/)
* Automatic transfers with the use of [FlexGet](http://flexget.com/)

![Pushover](https://pushover.net/assets/pushover-header-eaa79ef56c7041125acbe9fb9290b2fa.png)![FlexGet](http://flexget.com/chrome/site/FlexGet.png)

- - -
# Index
* [Requirements](#requirements)
* [Installation (Recommended)](#installation-recommended)
 * [Get svn](#get-svn)
 * [Manual install](#manual-install)
 * [Upgrading](#upgrading)
* [Configuration](#configuration)
 * [Single user](#single-users)
 * [Multiple users](#multiple-users)
 * [The config](#the-config)
* [Usage](#usage)
 * [Download single user](#download---single-user)
 * [Download multiple users](#download---multiple-users)
 * [Arguments](#arguments)
 * [Debugging](#debugging) 
* [Utils](#utils)
 * [Wakeonlan](#wakeonlan)
 * [Network Monitor](#network-monitor)
* [3rd party uses](#3rd-party-uses)
 * [FlexGet](#flexget)
  * [Download methods](#download-methods)
   * [Server download](#server-download)
   * [Clent RSS download](#cient-rss-download)
   * [Clent FTP download](#cient-ftp-download)
  * [Scheduling](#scheduling)
   * [Cron](#cron)
   * [Daemon](#Daemon)
  * [Multiple users](#multiple-users)


## Requirements
You should have User and sudo or root access to use and install, respectively.
Script is mainly written to Debian/Ubuntu and is guaranteed to work under these!

## Installation
There are several way to install FTPauto. Briefly summarized: The installer does just about everything for you. This is also the most stable version. You can also get the most recent version from git by pulling it.

### The installer (recommended)
To get FTPauto, download and execute the installer: [download](https://raw.github.com/Meliox/FTPauto/master/install.sh)
The installer will set up the environment and will help to install the necessary programs. During the installation you will also be able to set up a user!

```bash
mkdir FTPauto && cd FTPauto
wget https://raw.github.com/Meliox/FTPauto/master/install.sh
bash install.sh install
```

Follow the instructions to set up a user and then you're ready to use FTPauto! If you skipped user setup or need help go to [configuration](https://github.com/Meliox/FTPauto#configuration) to set up a user.

### Get svn
Alternatively, you can get it from Github (This version may contain unfinished features and be unstable).
```bash
git clone ssh://git@github.com/Meliox/FTPauto.git
```
Run
```bash 
bash install.sh install
```

### Manual install
If you prefer to do everything manually, read below.

The following programs are needed
```bash
rar lftp cksfv subversion automake1.9 fuse-utils libfuse-dev checkinstall libreadline-dev
```
Get them from your favourite repo or compile them yourself. However, rarfs needs to be compiled manually. This is showed below
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
If you want to upgrade to newest version, simply run
```bash
bash install.sh update
```

The same almost goes for git
```bash
git pull
bash install.sh update
```
NOTE: Running lastest version, doesn't mean it's 100% stable. 

# Configuration
First thing that need to be done is to create a user and edit the users settings. If you only want one user, you can leave <USERNAME> empty (default will be used). The setting that is to be edited is shown in [settings](https://github.com/Meliox/FTPauto#settings)

## Single user
Add users
```bash
bash ftpauto.sh --user= --add
```
## Multiple users
Add users
```bash
bash ftpauto.sh --user=<USERNAME> --add
```

Editing can be done by
```bash
bash ftpauto.sh --edit --user=<USERNAME>
```
Note: Editing can also be done manually after adding the user!
```bash
nano ~/users/<USERNAME>/config
```

Editing the config should be straight forward, but if you have troubles more info can be found here [The config](#the-config).
After this you may now start using FTPauto. See more [usage](#usage)

## The config
The most important setting is "transferetype".
Depending on the solution you can FTPauto can do
```
FTP	
	SERVER --> client   : upftp
	server <-- CLIENT   : downftp
FXP
	SERVER <-> client   : upfxp
	server <-> CLIENT   : downfxp
```
The capital letters state where FTPauto is executed and therefor giving the correct path is important. see [example](https://github.com/Meliox/FTPauto#transferetype-example)

The rest of the settings should explain themselves.
```bash
#This the the configuration file for FTPauto
config_version="4"
#Place the file in /home/ammin/scripts/ftpautodownload-dev/run/'mad'/config and load with --user='mad' or
# just load it with --config=config_path

#HOWTO: Edit the info between the qoutes "TEST", here the word TEST

#### FTP server Setup ####
 # If you just want the server to send <ITEM> to your ftp, edit the options below
transferetype="upftp or downftp or fxp" # Determine how to transfer file: Either send or receive from ftp or fxp them to another server

 # These directories are where you want to download/send the item. REMEMBER TRAILING SLASH
ftpincomplete="/shares/USB_Storage/temp/" # incomplete directory. Leave empty if no incomplete directory should be used
ftpcomplete="/shares/USB_Storage/Download/" # complete directory.

#### DOWN/UP MODE ####
 # If you just want to send/receive items, change these
ftpuser="user" # username
ftppass="pass" # password
ftphost="ip" # ipaddres for ftp server
ftpport="port" # ftp port
ssl="false" # Set to true to use ftps else set it to false

#### FXP MODE ####
 # If you just want to send/receive items from one server to another, change these also!
ftpuser2="user" # username
ftppass2="pass" # password
ftphost2="ip" # ipaddres for ftp server
ftpport2="port" # ftp port
ssl2="false" # use ftps or not

#### Log settings ###
logrotate="false" #enabled logrotating to move old to log.old
lognumber="50" #how many transfers to save in log before moving to log.old. 0 for disabled

#### Transfer settings ####

### Filehandling
 # Splitting files if filesize exceed MB. Some FTP servers disconnect after a certain amount of time is there is no
 # activity. These settings only work if the server handling the script also sends the files, i.e. in upftp and upfxp mode!
send_option="(video|split|default)" # Can be configured to send only videofile, split files according to settings or simply transfer the , default. If videofile or sizelimit are not met, then the files will be transfered as default - without any modifications.
video_file_to_complete="false" # Transfer videofile directly to complete directory. Only applies to video send_option
rarsplitlimit="1500" Determine how large files are allowed before the files are split. Only applies to split send_option
splitsize="100" # How large the rarparts should be in MB
create_sfv="true" # Create sfv for rarfiles

### Transfer settings

## General settings
parallel="3" # how many simultaneous transfers to download with
continue_queue="true" # Script will continue downloading if something is queued
retries="3" # How many times should the transfer be tried, before giving up
retry_download="10" # retry again in minutes after minimum space is reached OR server is offline.
retry_download_max="10" # retry for how many hours, before quitting

## Extra settings
force="false" # Transfer regardless of lockfiles/other transfers
confirm_transfer="false" # Try to confirm transfer
confirm_online="false" # Try to confirm that server is online/writeable before doing anything
exclude_array=( ) # Ignore certain files with name matching, format is ( "word1" "word2" )

## Extra settings
 # To enable FTP space info, ftpsizemanagement has to be set to true
totalmb="14950" # total ftp space
ftpsizemanagement="false" # will confirm enough free space in dir according to settings
critical="100" # minimum space before aborting transfer

## Processbar settings
 # Processbar shows how the transfer is proceeding, gives eta. etc.
sleeptime="60"  # how often to check transferproces. Time in seconds

## Miscellaneous settings
exec_post="" #Execute external command upon finish. See --help exec_pre for more info
allow_background="yes" # don't wait for exec to finish. ONLY for exec_post
exec_pre="" #Execute external command before starting. See --help for more info
sort="true" # Sort files into DVD/TV/etc/ or like defined in --sort=DIRECTORY. Changes can be made in the file /dependencies/sorting.sh

#### Push notifications ####
 # Create a user at https://pushover.net/ and enter details below
 # Leave push_user empty if you don't use it
push_token=""
push_user=""
```

## Transferetype-example

# Usage
Depending on you have multiple users or just a single user see sections below. A common feature is to use the common arguments listed here: [Arguments](#arguments)

### Download - single user
Now you can transfer something
```bash
bash ftpauto.sh --path=~/something/
```

### Download - multiple users
Now you can transfer something
```bash
bash ftpauto.sh --user=<USERNAME> --path=~/something/
```

More arguments are available, [arguments](#arguments).

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
       --queue           | Sends <PATH> to queue WITHOUT starting script.
                           NOTE that --path <ITEM> is required for this to work.
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
      --progress         | While transferring, this will print out progress if enabled in config	
      --quiet            | Suppresses all output
      --test             | Shows what transfer is going to happen
      --verbose          | Debugs to console
```
## Debugging
If the script for some reason should fail, it is easy to debug. Debugging can either be permanently set if the error comes and goes. This setting can be in ftpauto.sh, but altering the following line:
```bash
verbose="0" #0 Normal info | 1 debug console | 2 debug into logfile
```
* Line #3

Debugging into logfile will create a ftpscript logfile and a ftp logfile, so that everything can be looked at later. Debugging to console only will show script.

Debugging can also be used as an argument, see [Arguments](#arguments)

# Utils
A few usefull bashscripts has been added to FTPauto...
## Wakeonlan
```bash
# A simple shell to Wake Up nas devices / home servers
# Should be called with --ip="<IP-ADDRESS>" --macadr="<MAC-ADDRESS>" --port"<PORT>"
# ONLY <MAC-ADDRESS> is mandatory(on lan you mostlikely only need this)
# Remember to verify that the server supports wakeonlan
#     type: ethtool eth0 and if "Supports Wake-on: g" i present
#     you're good to go. Else type ethtool -s eth0 wol g to activate
#     and see again. If line is ok, you're good to go, else not working.
#     eth0 is the network interface, you might have others
# Example bash wakeonlan.sh -i "10.0.0.1" "30:11:32:08:15:74"
#
# Online WOL. Most routers forget the clients after a few minutes and that's why online wol
# rarely works. On my asus router you can hardcore the ip (static ofc.) with the mac adress
# with telnet/ssh like arp -s 192.168.0.1 00:30:c1:5e:68:74. And then after portforwarding
# it should work
#
# As a default setting to programs send 3 magic packets incase one is lost. Can be changed
# below
#settings
quiet="false"
packets="3"
```

## Network Monitor
Purpose of this script written i #SH is to monitor the network traffic and if the traffic is too low simple turn off your server.
```sh
# Network traffic monitor
# Purpose is to shut down server or do anything else if network traffic is below threshold due to
# low activity

# Do you want to monitor your netcard or the firewall? The netcard cannot see more traffic than
# allow by the bit of your system, i.e. 2^32 = 4gb. So 32bit is limited. A wrap has been used to
# fix this, but total traffic cannot be seen. Proper traffic count can be seen with iptables, but
# this requires to set op iptables rules like below
# Add monitor for INPUT and OUTPUT. REQUIRED!
# iptables -A INPUT -j ACCEPT
# iptables -A OUTPUT -j ACCEPT
#
# This assumes information is in third line like below. Edit line if this ins't the case
# Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
# pkts      bytes target     prot opt in     out     source               destination
# 1941988 1207873331 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0           state RELATED,ESTABLISHED
# 627   183690 ACCEPT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0
# 0        0 ACCEPT     all  --  eth0   *       0.0.0.0/0            0.0.0.0/0
# 0        0 ACCEPT     all  --  *      *       0.0.0.0/0            0.0.0.0/0
# 
# See your output by iptables -nx -vL <OUTPUT|INPUT>
#

#
# Settings below
#
threshold=10 		# MB per interval
monitor_time=5 		# mins per inverval
times=3 			# number of times it should be below threshold in each interval
lockfile="/volume3/homes/admin/scripts/networkmonitor.lock"
log="/volume3/homes/admin/scripts/networkmonitor.log"
shutdown_command="poweroff"	#command to execute

method="iptables" 	# iptables or netcard
interface="eth0" 	# only for netcard
line="3"			# only for iptables
```

# 3rd party uses
FTPauto can be used in combination with other software. Here are a few examples listed.
## FlexGet
FlexGet is a multi-purpose automation tool for content like torrents, nzbs, podcasts, comics, series, movies, etc. It can use different kinds of sources like RSS-feeds, html pages, csv files, search engines and there are even plugins for sites that do not provide any kind of useful feeds. Here we will use FlexGet to scan directories and let Flexget send the approved files. First prerequisite is to install Flexget, which can be found here [FlexGet#Install](http://flexget.com/wiki/InstallWizard/Linux/Environment/). Then an appropiate config has to be written as the following examples. More info on FlexGet and how it work is not going to be explained as it is done so very nicely on their homepage, [FlexGet#Configuration](http://flexget.com/wiki/Configuration/)

### Download methods
There are a few ways of downloading with the use of Flexget, these are explained in the subsections below.

One important thing to remember is to check if the config is writtten properly. Check it by
```bash
$ bin/flexget --test check
2014-01-10 11:15 INFO     check                         Config passed check.
```
And it will show if the config passes or fails.

#### Server download
This is a serverside configuration, meaning the server that has the files transfers the files.

```yaml
tasks:
 download:
  listdir: [~/TV/, ~/path2/]
  series:
    720p:
      - TVSHOW1
      - TVSHOW2
  exec:
    fail_entries: yes
    allow_background: yes
    auto_escape: yes
    on_output:
      for_accepted: 'sleep 5; bash ~/ftpauto.sh --path="{{location}}/" --user=<USER> --source=FLXDL &'
```

#### Client RSS download
This is a clientside configuration, meaning that the client looks for new files in order to transfer them.

```yaml
tasks:
  download:
    inputs:
      - rss:
          url: http://some.url.rss
    series:
      720p:
        - TVSHOW1
        - TVSHOW2
    manipulate:
        # Flexget can manipulate the url. If the url is made by flexget it usually has the original path written first.
	    # This can before with this
      - url:
          replace:
            regexp: 'file://<path before ftp path>/'
            format: '/'
    exec:
      fail_entries: yes
      allow_background: yes
      auto_escape: yes
      on_output:
        for_accepted: 'sleep 5; bash ~/ftpauto.sh --path="{{location}}/" --user=<USER> --source=FLXDL &'
```

#### Client FTP download
This is a clientside configuration, meaning that the client looks for new files in order to transfer them

```yaml
tasks:
  download:
    inputs:
      - ftp_list:
          config:
            use-ssl: <yes/no>
            name: <ftp name>
            username: <username>
            password: <password>
            host: <host to connect>
            port: <port>
          dirs:
            - <directory 1>
            - <directory 2>
    series:
	  # will download series with name and quality
	  720p:
        - <Tv show 1>
	    - <Tv show 2>
    regexp:
	  # will download anything that matches the giving regex
      accept:
	    - <regexp>:
            from:
              - title
	  # will not download matches of the giving regex
      accept:
	    - <regexp>:
            from:
              - title
    manipulate:
      - url:
          extract: (?:\:\d+\/)(.*)
    exec:
      fail_entries: yes
      allow_background: yes
      auto_escape: yes
      on_output:
        for_accepted: 'sleep 5; bash ~/ftpauto.sh --path="{{url}}/" --user=<USER> --source=FLXDL &'
```
Although flexget supports download from ftp also, FTPauto makes it possible to resume and sort downloads, also using the queue system and finally FTPauto can be used without Flexget.

### Scheduling
Flexget can be scheduled to run at specific times two different ways. Remember to make sure that your config passes check.

#### Cron
Add it to crontab and it may be added to crontab. Do this by and add this entry:
```bash
$ crontab -e
# write
*/5 * * * * ~/bin/flexget --cron
```
(Where 5 minutes is the interval checking for new files)

#### Daemon
Flexget also support daemon mode, which means that in can be run in the background, periodically running tasks on a schedule, or running the tasks initiated by another instance of FlexGet.

The following should then be added to your config
```yaml
schedules:
  - tasks: [list, of, tasks or * for all]
    interval:
      <weeks|days|hours|minutes>: <#>
      on_day: <monday|tuesday...>
      at_time: HH:MM [am|pm]  # 24h time can also be used
```
More information here [Flexget-daemon](http://flexget.com/wiki/Daemon)

### Multiple users
Flexget only handle one user PER show, so if several users see the same you need several configs. An addition argument then has to be used with the cron, daemon or check option
```bash
$ /bin/flexget -c ~<config path>
```
