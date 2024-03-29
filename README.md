# FTPauto

FTPauto is a simple, but highly advanced and configurable FTP-client wrap-around written in #Bash for Unix. It is based on [lftp](https://github.com/lavv17/lftp) and  helps to manage transfers.

# Features
* Send files easily with lftp (To and from FTP(s), and between serveres - FXP, and SFTP)
* Highly customizable command line optopns
* Monitor free space or server status on the remote server (pre/post check)
* Progressbar with estimated time of transferes
* History (Transfer logs, total transfered etc.)
* Queue manager for failed, queued transfere
* Packing/splitting directory/files into rar-files. Including sfv to verify files at end-server.
* Multiple user support
* Delay transfer to start at a specific time
* Support pre/post transfer using external scripts
* Sorting (regex-based or manually)
* Regex-based exclution of files or folders
* Seamless read-content from rar files using rar2fs fuse
* Send push notification to phones etc. with [Pushover](https://pushover.net/)
* Automatic transfers with the use of [FlexGet](http://flexget.com/)

If you find this tool helpful, a small donation is appreciated, [![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=K8XPMSEBERH3W).

![screenshot](https://cloud.githubusercontent.com/assets/5264368/25070558/36a0d0be-22a2-11e7-8629-da2b9aeba111.png)

- - -
# Index
* [Requirements](#requirements)
* [Installation (Recommended)](#installation-recommended)
 * [Get svn](#get-svn)
 * [Manual install](#manual-install)
 * [Upgrading](#upgrading)
* [Configuration](#configuration)
 * [Adding user](#adding-user)
 * [The config](#the-config)
* [Usage](#usage)
 * [Arguments](#arguments)
 * [Debugging](#debugging) 
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
There are several way to install FTPauto. Sudo is necesary to install some dependent tools

### The installer (recommended)
To get FTPauto, download and execute the installer: [download](https://raw.github.com/Meliox/FTPauto/master/install.sh)
The installer will set up the environment and will help to install the necessary programs. During the installation you will also be able to set up a user!

```bash
mkdir FTPauto && cd FTPauto
wget https://raw.github.com/Meliox/FTPauto/master/install.sh
bash install.sh install
```
and update
```bash
bash install.sh update
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

and update
```bash
git pull
bash install.sh update
```

# Configuration
First thing that need to be done is to create a user and edit the users settings. The setting that is to be edited is shown in [settings](https://github.com/Meliox/FTPauto#settings).

## Adding user
Add user:
```bash
bash ftpauto.sh --user=<USERNAME> --add
```

The users configuration must be edited prior use:
```bash
bash ftpauto.sh --edit --user=<USERNAME>
```
Note: Editing can also be done manually after adding the user!
```bash
nano ~/users/<USERNAME>/config
```

Editing the config should be straight forward, but if you have troubles more info can be found here [The config](#the-config).
After this you may now start using FTPauto. See more [usage](#usage).

## The config
The most important setting is "transferetype".
Depending on the solution you can FTPauto can do
```
FTP	
	SERVER --> client   : upftp(s) or upsftp
	server <-- CLIENT   : downftp(s)
FXP
	SERVER <-> server   : fxp
```
The capital letters state where FTPauto is executed and therefor giving the correct path is important. For FXP transferes ftphost1 is SERVER. For example, see [example](https://github.com/Meliox/FTPauto#transferetype-example)

The rest of the settings should be selfexplanatory. The config can be found here: https://github.com/Meliox/FTPauto/blob/master/dependencies/help.sh#L90.

## Transferetype-example

# Usage
After configuration transferes can be made as written below:
```bash
bash ftpauto.sh --user=<USERNAME> --path=~/something/
```
Several arguments can be used, see here: [arguments](#arguments).

## Arguments
Can be shown with:
```bash
bash ftpauto.sh --help
```
Here's an overview as well
```bash

== Required ==
        --user=<USER>      | Required at all times
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
        --delay            | Delays transfer until X. Has to be in this format 01/01/2010 12:00 (Month/Day/Year 24h-time)
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
If the script for some reason should fail, it is easy to debug. Debugging can either be permanently set if the error comes and goes. This setting can be in ftpauto.sh by altering the line 3:
```bash
verbose="0" #0 Normal info | 1 debug console | 2 debug into logfile
```

Debugging into logfile will create a ftpscript logfile and a ftp logfile, so that everything can be looked at later. Debugging to console only will show script.

Debugging may also be used as an argument, see [Arguments](#arguments).

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
