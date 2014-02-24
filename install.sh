#!/bin/bash
###
scriptdir=$(dirname $(readlink -f $0))
#
### code below
#
if [[ -f "$scriptdir/ftpauto.sh" ]]; then
	# local version
	i_version=$(sed -n '2p' "$scriptdir/ftpauto.sh")
	i_version=${i_version#$"s_version=\""}
	i_version=${i_version%\"}
else
	i_version=0
fi

control_c() {
	# run if user hits control-c
	echo -ne '\n'
	echo -e " \e[00;31mUser hit CTRL+C, exiting...\e[00m"
	echo " Run install.sh --uninstall to remove created files before trying again!"; echo ""
	exit 0
}
trap control_c SIGINT

#programs
function version_compare {
	local IFS=.
	local n1=($1) n2=($2)
	for i in ${!n1[@]}; do
		if [[ ${n1[i]} -gt ${n2[i]} ]]; then
			new_version="1"
			break
		elif [[ ${n1[i]} -lt ${n2[i]} ]]; then
			new_version="0"
		fi
	done
}

function lftp_update {
	if [[ -n $(builtin type -p lftp) ]]; then
		echo -n "Removing old version ..."
		sudo apt-get -y remove lftp &> /dev/null
		# remove compiled version
		sudo rm -rf "$scriptdir/dependencies/lftp*"
	fi
	sudo apt-get -y install checkinstall libreadline-dev &> /dev/null
	# find latest lftp
	cd "$scriptdir/dependencies"	
	local lftpversion=$(curl --silent http://lftp.yar.ru/ftp/ | egrep -o '>lftp.(.*).+tar.gz' | tail -1)
	lftpversion=${lftpversion#\>lftp\-}
	lftpversion=${lftpversion%.tar.gz}
	wget "http://lftp.yar.ru/ftp/lftp-$lftpversion.tar.gz" &> /dev/null
	tar -xzvf "lftp-$lftpversion.tar.gz" &> /dev/null
	rm "$scriptdir/dependencies/lftp-$lftpversion.tar.gz"
	cd "lftp-$lftpversion" && ./configure --with-openssl --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
}

function install_lftp {
	echo -n "Checking lftp ..."
	if [[ -z $(builtin type -p lftp) ]]; then
		echo -e " [\e[00;31mERROR\e[00m] lftp is not installed! lftp is needed for FTPauto to work!"
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
					echo "... Exiting"; echo ""; exit 1
				fi
			fi
			echo -n "Checking lftp .."
			if [[ -z $(builtin type -p $i) ]]; then
				echo -e " \e[00;32m [OK]\e[00m"
			fi
		else
			echo "FTPauto installation cannot continue without that. Exiting..."
			echo " Run install.sh --uninstall to remove created files";	echo ""
			exit 0
		fi
	else
		# get online lftp version
		local lftpversion=$(curl --silent http://lftp.yar.ru/ftp/ | egrep -o '>lftp.(.*).+tar.gz<' | tail -1)
		lftpversion=${lftpversion#\>lftp\-}
		lftpversion=${lftpversion%.tar.gz<}
		# get current lftp version
		local c_lftpversion=$(lftp --version | egrep -o 'Version\ [0-9].[0-9].[0-9]' | cut -d' ' -f2)
		version_compare "$lftpversion" "$c_lftpversion"
		if [[ "$new_version" -eq "1" ]]; then
			echo -e "[\e[00;33mv$lftpversion available, current version $c_lftpversion\e[00m] "
			read -p " Do you wish to update(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				lftp_update
			else
				echo -e "lftp update ... [\e[00;33mSKIPPED\e[00m]"
			fi
		else
			echo -e "\e[00;32m [lastest]\e[00m"x
		fi
	fi
}

function install_2 {
	# lftp
	install_lftp
	echo "Installing optional tools ..."
	# split files
	programs=( "rar" "cksfv" )
	for i in "${programs[@]}"; do
		echo -n "Checking $i ..."
		if [[ -z $(builtin type -p $i) ]]; then
			echo ""; echo -e " \"$i\" is not installed. It is required at servers end to split large files before sending them. Otherwise large file will be send normally"
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
	# for mouting to work
	echo -n "Checking rarfs ..."
	if [[ -z $(which rarfs) ]]; then
		echo ""; echo -n " \"rarfs\" is not installed! It is needed to send videofile only. The file will be transfered as normally otherwise"
		read -p " Do you want to install it(needs to be compiled - SLOW)(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			sudo apt-get -y install subversion automake1.9 fuse-utils libfuse-dev checkinstall &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo "INFO: Could not install program using sudo."
				echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
				echo "... Exiting"; echo ""; exit 0
			else
				cd "$scriptdir/dependencies/"
				wget http://downloads.sourceforge.net/project/rarfs/rarfs/0.1.1/rarfs-0.1.1.tar.gz &> /dev/null
				tar -xzvf rarfs-0.1.1.tar.gz &> /dev/null
				cd rarfs-0.1.1 && ./configure --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
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
	echo -n "Checking needed files ..."
	local main_files=("ftpauto.sh" "dependencies/ftp_online_test.sh" "dependencies/ftp_list.sh" "dependencies/ftp_size_management.sh" "dependencies/help.sh" "dependencies/largefile.sh" "dependencies/setup.sh" "dependencies/sorting.sh")
	# Confirm all files are present
	for i in "${main_files[@]}"; do
		if [[ ! -f "$scriptdir/$i" ]]; then
			echo "$i not found."; echo -e "\e[00;31mScript will not work without... Try reinstalling it. Exiting...\e[00m"; echo ""; exit 1;
		fi
	done
	echo -e "\e[00;32m [OK]\e[00m"
	echo "Finalizing ..."
	# Install default user
	read -p " Do you want to install a user? (You can add user later on)(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		read -p " What username do you want to use (leave empty for default)? "
		if [[ -n "$REPLY" ]]; then
			user="$REPLY"
		else
			user="default"
		fi
		echo -n "Adding user ..."
		echo -e "\e[00;32m [$user]\e[00m"
		source "$scriptdir/dependencies/help.sh"
		write_config
		echo -n "Checking user ..."
		if [[ ! -f "$scriptdir/users/$user/config/" ]]; then
			echo -e "\e[00;32m [OK]\e[00m"
			read -p " Do you want to configure that user now(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				nano "$scriptdir/users/$user/config"
			else
				echo "You can edit the user, by editing \"$scriptdir/users/$user/config\" or bash ftpauto.sh --user=$user --edit"
			fi
		else
			echo -e "\e[00;32m [OK]\e[00m User exists"
		fi

	else
		echo -e "Adding user ... [\e[00;33mSKIPPED\e[00m] NOTE: See ftpauto.sh --help for more info"
	fi

	echo ""
	echo -e "\e[00;32m [Installation done]\e[00m Enyoy! Start using FTPauto by using ftpauto.sh --help"
	echo ""
	exit 0
}
function install_1 {
	read -p " Do you wish to install(y/n)? "
	if [[ "$REPLY" == "n" ]]; then
		echo "... Exiting"; echo ""; exit 0
	fi
	echo ""
	
	# create directories
	echo -n "Creating directories ..."
	if [[ ! -d "$scriptdir/run" ]]; then mkdir "$scriptdir/run"; fi;
	if [[ ! -d "$scriptdir/users" ]]; then mkdir "$scriptdir/users"; fi;
	echo -e "\e[00;32m [OK]\e[00m"	
	
	# Install mandatory things that is needed for rest to work
	echo "Installing required tools ..."
	programs=( "bc" "curl" "openssl" )
	for i in "${programs[@]}"; do
		echo -n "Checking $i ..."
		if [[ -z $(builtin type -p $i) ]]; then
			echo -e "\e[00;31m[Not found]\e[00m"
			echo -n "Checking $i ..."
			sudo apt-get -y install $i &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo "INFO: Could not install program using sudo."
				echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
				echo "... Exiting"; echo ""; exit 0
			fi
			echo -e "\e[00;32m [OK]\e[00m"
			else
				echo -e "\e[00;31mScript will not work without... exiting\e[00m"; echo ""
				exit 0
			fi
		else
			echo -e "\e[00;32m [OK]\e[00m"
		fi
	done
	# ok we know have the required tools to update script
	update
	# continue  part2 of the installation
	install_2
}
function uninstall {
	local programs=("lftp" "bc" "rar" "cksfv" "rarfs" "subversion" "automake1.9" "fuse-utils" "libfuse-dev" "checkinstall" "libreadline-dev" "curl" "openssl")
	echo "The following will be removed: ${programs[@]}"
	read -p " Do you want to remove all or one by one(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		echo ""; echo -e "\e[00;31mWARNING: THIS WILL REMOVE ALL PROGRAMS, SOME MIGHT ALSO BE NEEDED BY OTHER PROGRAMS ON YOUR SYSTEMT.\e[00m"; echo "";
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
	sudo rm -rf "$scriptdir/dependencies/"
	sudo rm -rf "$scriptdir/plugins/"
	sudo rm -rf "$scriptdir/utils/"
	rm -f "$scriptdir/ftpauto.sh"
	rm -f "$scriptdir/LICENCE"
	rm -f "$scriptdir/README.md"
	rm -f "$scriptdir/ftpauto.sh"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n "Removing userfiles ..."
	rm -rf "$scriptdir/run"
	rm -rf "$scriptdir/users"
	echo -e "\e[00;32m [OK]\e[00m"
	echo ""
	echo "Removal complete!"
	echo ""
	exit 0
}
function download {
	echo -n " Downloading ..."
	wget -q "https://github.com/Meliox/FTPauto/archive/FTPauto-v$release_version.tar.gz"
	echo -e "\e[00;32m [OK]\e[00m"
	tar -xzf "$scriptdir"/FTPauto-v"$release_version.tar.gz" --overwrite --strip-components 1
	rm -f "$scriptdir"/FTPauto-v"$release_version.tar.gz"
	echo " Updated to v$release_version"
	echo -n "Extracting ..."
	echo -e "\e[00;32m [OK]\e[00m"
	bash "$scriptdir/install.sh" "install2"
}
function update {
	# get most recent stable version
	echo -n "Checking FTPauto ..."
	local release=$(curl --silent https://github.com/Meliox/FTPauto/releases | egrep -o 'FTPauto-v(.*)+tar.gz' | sort -n | tail -1)
	release_version=${release#$"FTPauto-v"}
	release_version=${release_version%.tar.gz}
	# comparasion
	version_compare "$release_version" "$i_version"
	if [[ "$i_version" == "0" ]]; then
		echo -e "\e[00;32m [New installation]\e[00m"
		download
	elif [[ "$new_version" -eq "1" ]]; then
		echo -e "\e[00;33m [v$release_version available]\e[00m"
		read -p " Do you want to update your version(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			download
		else
			echo -e "\e[00;33m [Present version kept]\e[00m"
		fi
	else
		echo -e "\e[00;32m [lastest]\e[00m"
		echo
		exit 0
	fi
}

function startupmessage {
	echo ""
	echo "Autoinstaller of FTPauto v$i_version"
	echo ""
}

case "$1" in
	uninstall)	startupmessage; uninstall;;
	install)	startupmessage; install_1;;
	install2)	install_2;;
	update)	update;;
	*)
		startupmessage; echo ""; echo "Usage: $0 (install | uninstall | update)"; echo "Run uninstall first to clean up everything if you have any problems."; echo "";
		exit 1
		;;
esac
