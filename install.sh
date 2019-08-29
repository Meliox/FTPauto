#!/bin/bash
###
scriptdir=$(dirname "$(readlink -f "$0")")
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
		for i in "${!n1[@]}"; do
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
	argument="$1"
	if [[ -n $(builtin type -p lftp) ]]; then
		# lftp is installed, compare installed version to newest version
		local lftpversion=$(curl --silent http://lftp.tech/ftp/ | grep -Eo '>lftp.(.*).+tar.gz<' | tail -1)
		lftpversion=${lftpversion#\>lftp\-}
		lftpversion=${lftpversion%.tar.gz<}
		# get current lftp version
		local c_lftpversion=$(lftp --version | grep -Eo 'Version\ [0-9].[0-9].[0-9]' | cut -d' ' -f2)
		version_compare "$lftpversion" "$c_lftpversion"
		if [[ "$new_version" == "true" ]]; then
			echo -e " [\e[00;33m$lftpversion available, current version $c_lftpversion\e[00m]"
			read -p " Do you wish to update(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				echo -n "Removing old version ..."
				sudo apt-get -y remove lftp &> /dev/null
				# remove compiled version
				sudo rm -rf "$scriptdir/dependencies/lftp*"
				argument="install"
			else
				echo -e " lftp update ... [\e[00;33mSKIPPED\e[00m]"
			fi
		else
			c_lftpversion=$(lftp --version | grep -Eo 'Version\ [0-9].[0-9].[0-9]' | cut -d' ' -f2)
			echo -e " \e[00;32m [Latest - v$c_lftpversion]\e[00m"
		fi
	fi

	if [[ "$argument" == "install" ]]; then
		sudo apt-get -y build-dep lftp &> /dev/null
		sudo apt-get -y install gcc openssl build-essential automake readline-common libreadline-dev pkg-config ncurses-dev libssl-dev libncurses5-dev libreadline-dev zlib1g-dev &> /dev/null
		# find latest lftp
		cd "$scriptdir/dependencies" || exit
		local lftpversion=$(curl --silent http://lftp.tech/ftp/ | grep -Eo '>lftp.(.*).+tar.gz' | tail -1)
		lftpversion=${lftpversion#\>lftp\-}
		lftpversion=${lftpversion%.tar.gz}
		wget "http://lftp.tech/ftp/lftp-$lftpversion.tar.gz" &> /dev/null
		tar -xzvf "lftp-$lftpversion.tar.gz" &> /dev/null
		rm "$scriptdir/dependencies/lftp-$lftpversion.tar.gz"
		cd "lftp-$lftpversion" && ./configure --with-openssl --silent &> /dev/null && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null
		echo -n " Checking for lftp ..."
		if [[ -n $(builtin type -p lftp) ]]; then
			echo -e " \e[00;32m [Latest - v$lftpversion]\e[00m"
		else
			echo -e "INFO: Could not install program using sudo.\nYou have to install \"lftp\" manually... Exiting\n"; exit 0
		fi
	fi
}

function install_lftp {
	echo -n " Checking/updating lftp ..."
	if [[ -z $(builtin type -p lftp) ]]; then
		echo -e "lftp is not installed! lftp is required for FTPauto to work!"
		read -p " Do you want to install it(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			read -p " Do you want latest version(needs to be compiled - SLOW - Any installed version will be removed) or the package from repo(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				lftp_update install
			else
				sudo apt-get -y install lftp &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "ERROR: Installation of lftp failed. Please install manually before continuing."
					echo -e "... Exiting\n"; exit 1
				fi
			fi
			echo -n "Checking lftp .."
			if [[ -z $(builtin type -p lftp) ]]; then
				echo -e " \e[00;32m [OK]\e[00m"
			fi
		else
			echo "FTPauto will not work without lftp. Exiting..."
			echo -e " Run install.sh uninstall to remove created files\n"
			exit 0
		fi
	else
		# lftp is installed, compare installed version to newest version
		lftp_update
	fi
}

function rar2fs_update {
	argument="$1"
	if [[ -n $(builtin type -p rar2fs) ]]; then
		# rar2fs is installed, compare installed version to newest version
		c_rar2fsversion=$(rar2fs --version 2> /dev/null | grep -Eo 'rar2fs\sv[0-9][0-9]?\.[0-9][0-9]?\.[0-9][0-9]?' | cut -d' ' -f2 | cut -d'v' -f2)
		rar2fsversion=$(curl -s https://api.github.com/repos/hasse69/rar2fs/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4 | cut -d '/' -f8 | cut -d'v' -f2)
		version_compare "$rar2fsversion" "$c_rar2fsversion"
		if [[ "$new_version" == "true" ]]; then
			echo -e " [\e[00;33m$rar2fsversion available, current version $c_rar2fsversion\e[00m]"
			read -p " Do you wish to update(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				if [[ -n $(builtin type -p rar2fs) ]]; then
					echo -n "Removing old version ..."
					sudo apt-get -y remove rar2fs &> /dev/null
					# remove compiled version
					sudo rm -rf "$scriptdir/dependencies/rar2fs*"
					argument="install"
				fi
			else
				echo -e " rar2fs update ... [\e[00;33mSKIPPED\e[00m]"
			fi
		else
			echo -e " \e[00;32m [Latest -v$rar2fsversion]\e[00m"
		fi
	fi
	if [[ "$argument" == "install" ]]; then
		# install
		cd "$scriptdir/dependencies/"
		# get latest stable release of rar2fs
		var=$(curl -s https://api.github.com/repos/hasse69/rar2fs/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4)
		wget -q "$var"
		name=$(basename "$var")
		tar zxf "$name" && rm "$name"
		name=${name::-7}
		cd "$name"
		#get unrar dependency for rar2fs
		wget -q http://www.rarlab.com/rar/unrarsrc-5.6.3.tar.gz && tar -zxf unrarsrc-5.6.3.tar.gz && rm unrarsrc-5.6.3.tar.gz
		cd unrar && make lib &> /dev/null && sudo make install-lib &> /dev/null && cd ..
		#compile rar2fs
		autoreconf -f -i &> /dev/null && ./configure --silent && make --silent && sudo checkinstall -y &> /dev/null
		echo -n " Checking for rar2fs ..."
		if [[ -n $(builtin type -p rar2fs) ]]; then
			c_rar2fsversion=$(rar2fs --version 2> /dev/null | grep -Eo 'rar2fs\sv[0-9][0-9]?\.[0-9][0-9]?\.[0-9][0-9]?' | cut -d' ' -f2 | cut -d'v' -f2)
			echo -e " \e[00;32m [Latest - v$c_rar2fsversion]\e[00m"
		else
			echo -e "INFO: Could not install program using sudo.\nYou have to install \"rar2fs\" manually... Exiting\n"; exit 0
		fi
	fi
}

function install_rar2fs {
	echo -n " Checking/updating rar2fs ..."
	if [[ -z $(builtin type -p rar2fs) ]]; then
		echo -e "\n \"rar2fs\" is not installed! It is needed to mount rarfiles in order to send videofile only. The file(s) will be transferred in original format otherwise"
		read -p " Do you want to install it(needs to be compiled - SLOW)(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			sudo apt-get -y install libfuse-dev autoconf &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\"\n... Exiting\n"; exit 0
			else
				rar2fs_update install
			fi
		else
			echo -e "Checking rar2fs ... [\e[00;33mSKIPPED\e[00m] NOTE: \"video\" will not work as send option"
		fi
	elif [[ -n $(builtin type -p rar2fs) ]]; then
		# rar2fs is installed, compare installed version to newest version
		rar2fs_update
	fi
}

function installDependencies {
	echo "Installing dependency tools ..."
	# create directories
	echo -n " Creating directories ..."
	mkdir -p "$scriptdir/run" "$scriptdir/users"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n " Checking dependencies files ..."
	local main_files=("ftpauto.sh" "dependencies/ftp_online_test.sh" "dependencies/ftp_list.sh" "dependencies/ftp_size_management.sh" "dependencies/help.sh" "plugins/largefile.sh" "dependencies/setup.sh" "dependencies/sorting.sh")
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
		if [[ -z $(builtin type -p "$i") ]]; then
			echo -e "\n \"$i\" is not installed. It is required for servers to split large files before sending them. Otherwise large file will be send normally"
			read -p " Do you want to install it(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				sudo apt-get -y install "$i" &> /dev/null
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
				fi
				if [[ -z $(builtin type -p "$i") ]]; then
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
	install_rar2fs

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

function install {
	read -p " Do you wish to install(y/n)? "
	if [[ "$REPLY" == "n" ]]; then
		echo -e "... Exiting\n"; exit 0
	fi

	# Install mandatory things that is needed for rest to work
	echo -e "\nInstalling minimum required tools ..."
	programs=( "bc" "curl" "openssl" "date" "tail" "awk" "mkdir" "sed" "tput" "nano" "cut" "checkinstall")
	for i in "${programs[@]}"; do
		echo -n " Checking for $i ..."
		if [[ -z $(builtin type -p "$i") ]]; then
			echo -e "\e[00;31m[Not found]\e[00m"
			sudo apt-get -y install "$i" &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\"... Exiting\n"; exit 0
			fi
			echo -n " Checking $i ..."
			if [[ -n $(builtin type -p "$i") ]]; then
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
	updateScript installNew
	# continue  part2 of the installation
	installDependencies
}

function uninstall {
	local programs=("lftp" "rar" "cksfv" "rar2fs" "pkg-config" "automake" "libfuse-dev" "checkinstall" "libssl-dev" "libncurses5-dev" "libreadline-dev" "zlib1g-dev" "autoconf")
	echo "The following will be removed: ${programs[@]}"
	read -p " Do you want to remove all or one by one(all=y/one-by-one(safe)=n)? "
	if [[ "$REPLY" == "y" ]]; then
		echo -e "\n\e[00;31mWARNING: THIS WILL REMOVE ALL PROGRAMS, SOME MIGHT ALSO BE NEEDED BY OTHER PROGRAMS ON YOUR SYSTEM :WARNING.\e[00m\n"
		read -p " ARE YOU SURE?(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			for i in "${programs[@]}"; do
				sudo apt-get -y remove "$i" &> /dev/null
				echo -e "$i \e[00;32m[REMOVED]\e[00m"
			done
		fi
	else
		for i in "${programs[@]}"; do
			if builtin type -p "$i" &>/dev/null; then
				echo -n "Removing $i ..."
				read -p " Do you want to remove it(y/n)? "
				if [[ "$REPLY" == "y" ]]; then
					sudo apt-get -y remove "$i" &> /dev/null
					echo -e "\e[00;32m [REMOVED]\e[00m"
				else
					echo -e "\e[00;33m [KEPT]\e[00m"
				fi
			fi
		done
	fi
	echo -n "Removing sourcefiles ..."
	sudo rm -rf "$scriptdir/dependencies/" "$scriptdir/plugins/"
	rm -f "$scriptdir/ftpauto.sh" "$scriptdir/LICENCE" "$scriptdir/README.md" "$scriptdir/ftpauto.sh"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n "Removing userfiles ..."
	rm -rf "$scriptdir/run" "$scriptdir/users"
	echo -n "Removing remainder of FTPauto ..."
	rm -rf "$scriptdir"	
	echo -e "\e[00;32m [OK]\e[00m\nComplete removal of FTPauto and dependencies complete!\n"
	exit 0
}

function downloadScript {
	echo -n " Downloading FTPauto..."
	wget -q "https://github.com/Meliox/FTPauto/archive/FTPauto-v$release_version.tar.gz"
	echo -e "\e[00;32m [OK]\e[00m"
	echo -n " Extracting ..."
	tar -xzf "${scriptdir}/FTPauto-v${release_version}.tar.gz" --overwrite --strip-components 1
	rm -f "${scriptdir}/FTPauto-v${release_version}.tar.gz"
	echo -e "\e[00;32m [OK]\e[00m"
	sed "6c lastUpdate=$(date +'%s')" -i "$scriptdir/ftpauto.sh" # set update time
	sed "7c message=\"\"" -i "$scriptdir/ftpauto.sh" # reset update message
	echo -e "\nPlease execute installer again.\n";
	exit 0;
}

function updateScript {
	argument="$1"
	getCurrentVersion
	# get most recent stable version from git
	echo -n " Checking/updating FTPauto ..."
	local release=$(curl --silent https://github.com/Meliox/FTPauto/releases | grep -Eo 'FTPauto-v(.*)+tar.gz' | sort -n | tail -1)
	release_version=${release#$"FTPauto-v"}
	release_version=${release_version%.tar.gz}
	version_compare "$release_version" "$i_version"
	# compare to local version
	if [[ "$i_version" == "0" ]] && [[ $argument != installNew ]]; then
		echo -e "\e[00;31m [ERROR]\e[00m\nNo installation found. Execute script with install as argument instead. Exiting.\n"
		exit 0
	elif [[ "$new_version" == "true" ]] && [[ $argument == installNew ]]; then
		echo -e "\e[00;32m [Found - v$release_version]\e[00m"
		downloadScript
	elif [[ "$new_version" == "true" ]]; then
		echo -e "\e[00;33m [$release_version available]\e[00m"
		read -p " Do you want to update your version(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			downloadScript
		else
			echo -e "\e[00;33m [Local version kept]\e[00m"
		fi
	else
		echo -e "\e[00;32m [Latest - v$i_version]\e[00m"
		sed "6c lastUpdate=$(date +'%s')" -i "$scriptdir/ftpauto.sh" # set update time
		sed "7c message=\"\"" -i "$scriptdir/ftpauto.sh" # reset update message
	fi
}

function update {
	updateScript
	install_rar2fs
	install_lftp
	echo -e "\n\e[00;32m[Update done]\e[00m\nEnjoy! Start using FTPauto by using ftpauto.sh --help\n"
	exit 0
}

function startupmessage {
	echo -e "\nAutoinstaller for FTPauto\n"
}

getCurrentVersion
case "$1" in
	uninstall) startupmessage; uninstall;;
	install) startupmessage; install;;
	update)	startupmessage; update;;
	*)
		startupmessage; echo -e "\nUsage: $0 (install | uninstall | update)\nExecute uninstall first to clean up everything if you encounter any problems.\n";
		exit 1
		;;
esac
