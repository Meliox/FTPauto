#!/bin/bash
###
scriptdir=$(dirname $(readlink -f $0))
#
### code below
#
if [[ -f "$scriptdir/ftpauto.sh" ]]; then
	i_version=$(sed -n '2p' "$scriptdir/ftpauto.sh")
	i_version=${i_version#$"s_version=\""}
	i_version=${i_version%\"}
else
	i_version=0
fi

# main programs needed
function install {
	update
	read -p " Do you wish to continue(y/n)? "
	if [[ "$REPLY" == "n" ]]; then
		echo "... Exiting"; echo ""; exit 0
	fi
	# lftp
	echo -n "Checking lftp ..."
	if [[ -z $(which lftp) ]]; then
		echo -e " [\e[00;31mERROR\e[00m] \"lftp\" is not installed! It is needed for ftpautodownload to work"
		read -p " Do you want to install it(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			read -p " Do you want latest version(y)(needs to be compiled - SLOW - Any installed version will be removed) or the package from repo(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				if ! builtin type -p lftp &>/dev/null; then
					sudo apt-get -y remove lftp &> /dev/null
				fi
				cd $scriptdir/dependencies
				sudo apt-get -y install checkinstall libreadline-dev &> /dev/null
				wget http://lftp.yar.ru/ftp/lftp-4.4.8.tar.gz &> /dev/null
				rm lftp-4.4.8.tar.gz
				tar -xzvf lftp-4.4.8.tar.gz &> /dev/null
				cd lftp-4.4.8 && ./configure --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
			else
				sudo apt-get -y install lftp &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
					echo "... Exiting"; echo ""; exit 1
				fi
			fi
			if builtin type -p lftp &>/dev/null; then
				echo -e " \e[00;32m [OK]\e[00m"
			fi
		fi
	fi
	echo -e "\e[00;32m [OK]\e[00m"
	# other programs
	programs=("rar" "cksfv")
	for i in "${programs[@]}"; do
		echo -n "Checking $i ..."
		if ! builtin type -p $i &>/dev/null; then
			echo -e "\e[00;31m[ERROR]\e[00m \"$i\" is not installed"
			read -p " Do you want to install it(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				sudo apt-get -y install $i &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
					echo "... Exiting"; echo ""; exit 0
				fi
				if builtin type -p $i &>/dev/null; then
					echo -e " \e[00;32m [OK]\e[00m"
				fi				
			else
				echo -e "\e[00;31mScript will not work without... exiting\e[00m"; echo ""
				exit 0
			fi
		else
			echo -e "\e[00;32m [OK]\e[00m"
		fi
	done	
	# for mouting to work
	echo -n "Checking rarfs ..."
	if [[ -z $(which rarfs) ]]; then
		echo -e " [\e[00;31m[ERROR]\e[00m] \"rarfs\" is not installed! It is needed for \"videofile only\" to work. The file will be transfered as normally otherwise"
		read -p " Do you want to install it(needs to be compiled - SLOW)(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			sudo apt-get -y install subversion automake1.9 fuse-utils libfuse-dev checkinstall &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo "INFO: Could not install program using sudo."
				echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
				echo "... Exiting"; echo ""; exit 0
			else
				cd $scriptdir/dependencies/
				wget http://downloads.sourceforge.net/project/rarfs/rarfs/0.1.1/rarfs-0.1.1.tar.gz &> /dev/null
				tar -xzvf rarfs-0.1.1.tar.gz &> /dev/null
				cd rarfs-0.1.1 && ./configure --silent && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
				rm $scriptdir/dependencies/rarfs-0.1.1.tar.gz
				read -p "Which user would you like to run this program at(no spaces)? "
				sudo adduser $REPLY fuse &> /dev/null
				sudo chgrp fuse /dev/fuse &> /dev/null
				sudo chgrp fuse /dev/fuse &> /dev/null
				sudo chgrp fuse /bin/fusermount &> /dev/null
				sudo chmod u+s /bin/fusermount &> /dev/null
			fi
		else
			echo -e "Checking rarfs ... [\e[00;33mSKIPPED\e[00m] NOTE: \"videofile only\" will not work"
		fi
		if builtin type -p $i &>/dev/null; then
			echo -e " \e[00;32m [OK]\e[00m"
		fi
	fi
	echo -e "\e[00;32m [OK]\e[00m"
	# create directories
	echo -n "Creating directories ..."
	if [[ ! -d "$scriptdir/run" ]]; then mkdir "$scriptdir/run"; fi;
	if [[ ! -d "$scriptdir/users" ]]; then mkdir "$scriptdir/users"; fi;
	echo -e "\e[00;32m [OK]\e[00m"
	# Confirm all files are present
	echo -n "Checking needed files ..."
	local main_files=("dependencies/ftpauto.sh" "dependencies/ftp_online_test.sh" "dependencies/ftp_size_management.sh" "dependencies/help.sh" "dependencies/largefile.sh" "dependencies/setup.sh" "dependencies/sorting.sh")
	for i in "${main_files[@]}"; do
		if [[ ! -f "$scriptdir/$i" ]]; then
			echo "$i not found."; echo -e "\e[00;31mScript will not work without... exiting\e[00m"; echo ""; exit 1;
		fi
	done
	echo -e "\e[00;32m [OK]\e[00m"
	# Install default user
	read -p " Do you want to install a user. You can add user later on(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		read -p " What username do you want to use (leave empty for default)? "
		if [[ -n "$REPLY" ]]; then
			user="$REPLY"
		else
			user="default"
		fi
		echo -n "Adding user ..."
		bash "$scriptdir/ftpauto.sh" --add --user="$user" &> /dev/null
		echo -e "\e[00;32m [OK]\e[00m NOTE: User="$user""
		read -p " Do you want to configure that user now(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			nano $scriptdir/users/$user/config
		else
			echo "You can edit the user, by editing \"$scriptdir/users/$user/config\""
		fi
	else
		echo -e "Adding user ... [\e[00;33mSKIPPED\e[00m] NOTE: See ftpauto.sh --help for more info"
	fi
	
	echo ""
	echo "Installation done. Enyoy! Start using ftpautodownload by using ftpauto.sh. For more info see --help"
	echo ""
}
function uninstall {
	local programs=("lftp" "rar" "cksfv" "rarfs" "subversion" "automake1.9" "fuse-utils" "libfuse-dev" "checkinstall" "libreadline-dev")
	echo "The following will be removed: ${programs[@]}"
	read -p " Do you want to remove all or one by one(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		for i in "${programs[@]}"; do
			sudo apt-get -y remove $i &> /dev/null
		done
			echo -e "\e[00;32m [REMOVED]\e[00m"
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
	sudo rm -rf $scriptdir/dependencies/rarfs-0.1.1
	sudo rm -rf $scriptdir/dependencies/lftp-4.4.8
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n "Removing userfiles ..."
	rm -rf $scriptdir/run
	rm -rf $scriptdir/users
	echo -e "\e[00;32m [OK]\e[00m"
	echo ""
	echo "Removal complete!"
	echo ""
	exit 0
}
function update {
	# get most recent stable version
	echo -n "Checking for new stable version ..."
	local release=$(curl --silent https://github.com/Meliox/FTPauto/releases | egrep -o 'FTPauto-v[-.0-9]+tar.gz' | sort -n | tail -1)
	release_version=${release#$"FTPauto-v"}
	release_version=${release_version%.tar.gz}
	# local version
	local version=$(sed -n '2p' "$scriptdir/ftpauto.sh")
	version=${version#$"s_version=\""}
	version=${version%\"}
	# comparasion
	if [[ "$( echo "$release_version > $version" | bc)" -eq "1" ]]; then
		echo -e "\e[00;33m [$version available]\e[00m"
		read -p " Do you want to update your version(y/n)? "
		if [[ "$REPLY" == "y" ]]; then		
			wget -q "https://github.com/Meliox/FTPauto/archive/FTPauto-v$release_version.tar.gz"
			echo tar -xzf "$scriptdir"/FTPauto-v"$release_version.tar.gz" --overwrite --strip-components 1
			rm -f "$scriptdir"/FTPauto-v"$release_version.tar.gz"
			echo "Updated to v$release_version"
			echo "Installing ..."
			echo " (only to confirm tools are still installed and working and adding new programs if needed)"
			bash "$scriptdir/install.sh" install
		else
			echo -e "\e[00;33m [Present version kept]\e[00m"
		fi
	else
		echo -e "\e[00;32m [You have lastest]\e[00m"
	fi	
}

echo ""
echo "Autoinstaller v$i_version for FTPauto"
echo ""	
case "$1" in
	uninstall)	uninstall;;
	install)	install;;
	update)update;;
	*)
		echo ""; echo "Usage: $0 (install | uninstall | update)"; echo "";
		exit 1
		;;
esac