#!/bin/bash
###
scriptdir=$(dirname $(readlink -f $0))
#
### code below
#
function getCurrentVersion {
if [[ -f "$scriptdir/ftpauto.sh" ]]; then
	# local version
	i_version=$(sed -n '2p' "$scriptdir/ftpauto.sh")
	i_version=${i_version#$"s_version=\""}
	i_version=${i_version%\"}
else
	i_version=0
fi
}
control_c() {
	# run if user hits control-c
	echo -ne '\n'
	echo -e " \e[00;31mUser hit CTRL+C, exiting...\e[00m"
	echo -e " Run install.sh uninstall to remove created files before trying again!\n"
	exit 0
}
trap control_c SIGINT

#programs
function version_compare {
	if [[ "$1" == "$2" ]]; then
		# Uptodate
		new_version="false"
	else
		local IFS=.
		local n1=($1) n2=($2)
		for i in ${!n1[@]}; do
			if [[ ${n1[i]} -gt ${n2[i]} ]]; then
				new_version="true"
				break
			elif [[ ${n1[i]} -lt ${n2[i]} ]]; then
				new_version="false"
			fi
		done
	fi
}

function lftp_update {
	if [[ -n $(builtin type -p lftp) ]]; then
		echo -n "Removing old version ..."
		sudo apt-get -y remove lftp &> /dev/null
		# remove compiled version
		sudo rm -rf "$scriptdir/dependencies/lftp*"
	fi
	sudo apt-get -y build-dep lftp
	sudo apt-get -y install gcc openssl build-essential automake readline-common libreadline6-dev pkg-config libgnutls-dev ncurses-dev &> /dev/null
	# find latest lftp
	cd "$scriptdir/dependencies"
	local lftpversion=$(curl --silent http://lftp.tech/ftp/ | egrep -o '>lftp.(.*).+tar.gz' | tail -1)
	lftpversion=${lftpversion#\>lftp\-}
	lftpversion=${lftpversion%.tar.gz}
	wget "http://lftp.tech/ftp/lftp-$lftpversion.tar.gz" &> /dev/null
	tar -xzvf "lftp-$lftpversion.tar.gz" &> /dev/null
	rm "$scriptdir/dependencies/lftp-$lftpversion.tar.gz"
	cd "lftp-$lftpversion" && ./configure --with-openssl --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
}

function install_lftp {
	echo -n " Checking/updating lftp ..."
	if [[ -z $(builtin type -p lftp) ]]; then
		echo -e "lftp is not installed! lftp is required for FTPauto to work!"
		read -p " Do you want to install it(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			read -p " Do you want latest version(y)(needs to be compiled - SLOW - Any installed version will be removed) or the package from repo(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				lftp_update
			else
				sudo apt-get -y install lftp &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
					echo -e "... Exiting\n"; exit 1
				fi
			fi
			echo -n "Checking lftp .."
			if [[ -z $(builtin type -p $i) ]]; then
				echo -e " \e[00;32m [OK]\e[00m"
			fi
		else
			echo "FTPauto installation cannot continue without that. Exiting..."
			echo -e " Run install.sh uninstall to remove created files\n"
			exit 0
		fi
	else
		# get online lftp version
		local lftpversion=$(curl --silent http://lftp.tech/ftp/ | egrep -o '>lftp.(.*).+tar.gz<' | tail -1)
		lftpversion=${lftpversion#\>lftp\-}
		lftpversion=${lftpversion%.tar.gz<}
		# get current lftp version
		local c_lftpversion=$(lftp --version | egrep -o 'Version\ [0-9].[0-9].[0-9]' | cut -d' ' -f2)
		version_compare "$lftpversion" "$c_lftpversion"
		if [[ "$new_version" == "true" ]]; then
			echo -e " [\e[00;33mv$lftpversion available, current version $c_lftpversion\e[00m] "
			read -p " Do you wish to update(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				lftp_update
			else
				echo -e " lftp update ... [\e[00;33mSKIPPED\e[00m]"
			fi
		else
			echo -e " \e[00;32m [Latest]\e[00m"
		fi
	fi
}

function installContinue {
	echo "Installing dependency tools ..."
	# create directories
	echo -n " Creating directories ..."
	mkdir -p "$scriptdir/run" "$scriptdir/users"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n " Checking dependencies files ..."
	local main_files=("ftpauto.sh" "dependencies/ftp_online_test.sh" "dependencies/ftp_list.sh" "dependencies/ftp_size_management.sh" "dependencies/help.sh" "dependencies/largefile.sh" "dependencies/setup.sh" "dependencies/sorting.sh")
	# Confirm all files are present
	for i in "${main_files[@]}"; do
		if [[ ! -f "$scriptdir/$i" ]]; then
			echo -e "\n\e[00;31m$i not found.\nScript will not work without... Try reinstalling it. Exiting...\e[00m\n"; exit 1;
		fi
	done
	echo -e "\e[00;32m [OK]\e[00m"

	# lftp
	install_lftp

	echo "Installing optional tools ..."
	# split files
	programs=( "rar" "cksfv" )
	for i in "${programs[@]}"; do
		echo -n " Checking $i ..."
		if [[ -z $(builtin type -p $i) ]]; then
			echo -e "\n \"$i\" is not installed. It is required at servers end to split large files before sending them. Otherwise large file will be send normally"
			read -p " Do you want to install it(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				sudo apt-get -y install $i &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
				fi
				if [[ -z $(builtin type -p $i) ]]; then
					echo -e " \e[00;32m [OK]\e[00m"
				fi
			else
				echo -e "Checking $i ... [\e[00;33mSKIPPED\e[00m] NOTE: \"split_files\" and \"create_sfv\" will not work"
				break
			fi
		else
			echo -e "\e[00;32m [OK]\e[00m"
		fi
	done
	# for mounting to work
	echo -n " Checking rarfs ..."
	if [[ -z $(which rarfs) ]]; then
		echo -e "\n \"rarfs\" is not installed! It is needed to mount rarfiles in order to only send videofile. The file(s) will be transferred as normally otherwise"
		read -p " Do you want to install it(needs to be compiled - SLOW)(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			sudo apt-get -y install automake1.9 fuse-utils libfuse-dev &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\"\n... Exiting\n"; exit 0
			else
				cd "$scriptdir/dependencies/"
				wget https://github.com/vadmium/rarfs/releases/download/0.1.1/rarfs-0.1.1.tar.gz &> /dev/null
				tar -xzvf rarfs-0.1.1.tar.gz &> /dev/null
				cd rarfs-0.1.1 && autoreconf --install && ./configure --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
				rm "$scriptdir/dependencies/rarfs-0.1.1.tar.gz"
				read -p "Which user would you like to run this program at(no spaces)? "
				sudo adduser $REPLY fuse &> /dev/null
				sudo chgrp fuse /dev/fuse &> /dev/null
				sudo chgrp fuse /dev/fuse &> /dev/null
				sudo chgrp fuse /bin/fusermount &> /dev/null
				sudo chmod u+s /bin/fusermount &> /dev/null
			fi
		else
			echo -e "Checking rarfs ... [\e[00;33mSKIPPED\e[00m] NOTE: \"videofile_only\" will not work"
		fi
		if [[ -z $(builtin type -p rarfs) ]]; then
			echo -e " \e[00;32m [OK]\e[00m"
		fi
	else
		echo -e "\e[00;32m [OK]\e[00m"
	fi

	echo "Finalizing ..."
	# Install default user
	read -p " Do you want to install a user? (You can add user later on)(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		read -p " What username do you want to use (leave empty for "default")? "
		if [[ -n "$REPLY" ]]; then
			username="$REPLY"
		else
			username="default"
		fi
		echo -n " Adding user, $username ..."
		source "$scriptdir/dependencies/help.sh"
		write_config
		if [[ -f "$scriptdir/users/$username/config" ]]; then
			read -p " Do you want to configure $user now(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				nano "$scriptdir/users/$user/config"
			else
				echo "NOTE: You can edit the user later using bash ftpauto.sh --user=$user --edit"
			fi
		else
			echo -e "\nUser already exists"
		fi

	else
		echo -e " Adding user ... [\e[00;33mSKIPPED\e[00m] NOTE: See ftpauto.sh --help for more info"
	fi
	echo -e "\n\e[00;32m[Installation done]\e[00m\nEnjoy! Start using FTPauto by using ftpauto.sh --help\n"
	exit 0
}
function installStart {
	read -p " Do you wish to install(y/n)? "
	if [[ "$REPLY" == "n" ]]; then
		echo -e "... Exiting\n"; exit 0
	fi

	# Install mandatory things that is needed for rest to work
	echo -e "\nInstalling minimum required tools ..."
	programs=( "bc" "curl" "openssl" "date" "tail" "awk" "mkdir" "sed" "tput" "nano" "cut" "checkinstall")
	for i in "${programs[@]}"; do
		echo -n " Checking for $i ..."
		if [[ -z $(builtin type -p $i) ]]; then
			echo -e "\e[00;31m[Not found]\e[00m"
			sudo apt-get -y install $i &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\"\n... Exiting\n"; exit 0
			fi
			echo -n "Checking $i ..."
			if [[ -n $(builtin type -p $i) ]]; then
				echo -e "\e[00;32m [OK]\e[00m"
			else
				echo -e "\e[00;31mScript will not work without... exiting\e[00m\n"
				exit 0
			fi
		else
			echo -e "\e[00;32m [OK]\e[00m"
		fi
	done
	# ok we know have the required tools to update script
	update
	# continue  part2 of the installation
	installContinue
}
function uninstall {
	local programs=("lftp" "nano" "rar" "cksfv" "rarfs" "subversion" "gcc" "build-essential" "ncurses-dev" "readline-common" "pkg-config" "automake" "fuse-utils" "libfuse-dev" "checkinstall" "libreadline-dev" "curl" "openssl")
	echo "The following will be removed: ${programs[@]}"
	read -p " Do you want to remove all or one by one(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		echo -e "\n\e[00;31mWARNING: THIS WILL REMOVE ALL PROGRAMS, SOME MIGHT ALSO BE NEEDED BY OTHER PROGRAMS ON YOUR SYSTEMT.\e[00m\n"
		read -p " ARE YOU SURE?(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			for i in "${programs[@]}"; do
				sudo apt-get -y remove $i &> /dev/null
				echo -e "$i \e[00;32m[REMOVED]\e[00m"
			done
		fi
	else
		for i in "${programs[@]}"; do
			if builtin type -p $i &>/dev/null; then
				echo -n "Removing $i ..."
				read -p " Do you want to remove it(y/n)? "
				if [[ "$REPLY" == "y" ]]; then
					sudo apt-get -y remove $i &> /dev/null
					echo -e "\e[00;32m [REMOVED]\e[00m"
				else
					echo -e "\e[00;33m [KEPT]\e[00m"
				fi
			fi
		done
	fi
	echo -n "Removing sourcefiles ..."
	sudo rm -rf "$scriptdir/dependencies/" "$scriptdir/plugins/" "$scriptdir/utils/"
	rm -f "$scriptdir/ftpauto.sh" "$scriptdir/LICENCE" "$scriptdir/README.md" "$scriptdir/ftpauto.sh"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n "Removing userfiles ..."
	rm -rf "$scriptdir/run" "$scriptdir/users"
	echo -e "\e[00;32m [OK]\e[00m\nRemoval complete!\n"
	exit 0
}
function download {
	echo -n " Downloading FTPauto..."
	wget -q "https://github.com/Meliox/FTPauto/archive/FTPauto-v$release_version.tar.gz"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n " Extracting ..."
	tar -xzf "$scriptdir"/FTPauto-v"$release_version.tar.gz" --overwrite --strip-components 1
	rm -f "$scriptdir"/FTPauto-v"$release_version.tar.gz"
	echo -e "\e[00;32m [OK]\e[00m"
	update
	installContinue
}
function update {
	getCurrentVersion
	# get most recent stable version
	echo -n " Checking/updating FTPauto ..."
	local release=$(curl --silent https://github.com/Meliox/FTPauto/releases | egrep -o 'FTPauto-v(.*)+tar.gz' | sort -n | tail -1)
	release_version=${release#$"FTPauto-v"}
	release_version=${release_version%.tar.gz}
	# comparasion
	version_compare "$release_version" "$i_version"
	if [[ "$i_version" == "0" ]] && [[ $argument != install ]]; then
		echo -e "\e[00;31m [ERROR]\e[00m\nNo installation found. Execute script with install as argument instead. Exiting.\n"
		exit 0
	elif [[ $argument == install ]]; then
		echo -e "\e[00;32m [Found $release_version]\e[00m"
		argument=continue
		download
		sed "6c lastUpdate=$(date +'%s')" -i "$scriptdir/ftpauto.sh" # set update time
		sed "7c message=\"\"" -i "$scriptdir/ftpauto.sh" # reset update message		
	elif [[ "$new_version" == "true" ]]; then
		echo -e "\e[00;33m [$release_version available]\e[00m"
		read -p " Do you want to update your version(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			download
		else
			echo -e "\e[00;33m [Local version kept]\e[00m"
		fi
	else
		echo -e "\e[00;32m [Latest]\e[00m"
		sed "6c lastUpdate=$(date +'%s')" -i "$scriptdir/ftpauto.sh" # set update time
		sed "7c message=\"\"" -i "$scriptdir/ftpauto.sh" # reset update message
	fi
}

function startupmessage {
	echo -e "\nAutoinstaller for FTPauto\n"
}

getCurrentVersion
argument=$1
case "$1" in
	uninstall) startupmessage; uninstall;;
	install) startupmessage; installStart;;
	update)	startupmessage; update;;
	*)
		startupmessage; echo -e "\nUsage: $0 (install | uninstall | update)\nExecute uninstall first to clean up everything if you encounter any problems.\n";
		exit 1
		;;
esac
