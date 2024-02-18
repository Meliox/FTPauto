#!/bin/bash

# Get the directory of the script
scriptdir=$(dirname "$(readlink -f "$0")")

# Function to get the current version of FTPauto
function getCurrentVersion {
	if [[ -f "$scriptdir/ftpauto.sh" ]]; then
		# Get local version
		i_version=$(sed -n '2p' "$scriptdir/ftpauto.sh")
		i_version=${i_version#$"s_version=\""}
		i_version=${i_version%\"}
	else
		i_version=0
	fi
}

# Function to handle Ctrl+C interruption
function control_c() {
	echo -ne '\n'
	echo -e " \e[00;31mUser hit CTRL+C, exiting...\e[00m"
	echo -e " Run install.sh uninstall to remove created files before trying again!\n"
	exit 0
}
trap control_c SIGINT

# Function to compare versions
function version_compare {
    if [[ "$1" == "$2" ]]; then
        new_version="false"
    else
        local IFS=.
        local n1=($1) n2=($2)
        local len=${#n1[@]}
        for ((i=0; i<$len; i++)); do
            if [[ ${n1[i]:-0} -gt ${n2[i]:-0} ]]; then
                new_version="true"
                break
            elif [[ ${n1[i]:-0} -lt ${n2[i]:-0} ]]; then
                new_version="false"
                break
            fi
        done
    fi
}

# Function to install/update lftp
function lftp_update {
    argument="$1"

    # Check if lftp is installed
    if [[ -n $(command -v lftp) ]]; then
        # Get the latest version of lftp from GitHub
        local lftpversion=$(curl -s https://github.com/lavv17/lftp/tags | grep -oP '(?<=tags/v)\d+\.\d+\.\d+' | sort -V | tail -n 1)
        # Get the current version of lftp
        local c_lftpversion=$(lftp --version | grep -Eo 'Version\ [0-9].[0-9].[0-9]' | cut -d' ' -f2)
        # Compare versions
        version_compare "$lftpversion" "$c_lftpversion"

        if [[ "$new_version" == "true" ]]; then
            # Prompt user to update lftp
            echo -e " [\e[00;33m$lftpversion available, current version $c_lftpversion\e[00m]"
            read -p " Do you wish to update (y/n)? "

            if [[ "$REPLY" == "y" ]]; then
                # Remove old version of lftp
                echo -n "Removing old version ..."
                sudo apt-get -y remove lftp &> /dev/null
                sudo rm -rf "$scriptdir/dependencies/lftp*"
                argument="install"
            else
                echo -e " lftp update ... [\e[00;33mSKIPPED\e[00m]"
            fi
        else
            # Display that lftp is up to date
            echo -e " \e[00;32m [Latest - v$c_lftpversion]\e[00m"
        fi
    fi

    # Install lftp if specified or if it's not installed
    if [[ "$argument" == "install" ]]; then
        # Install required dependencies
        sudo apt-get -y build-dep lftp &> /dev/null
        sudo apt-get -y install gcc openssl build-essential automake readline-common libreadline-dev pkg-config ncurses-dev libssl-dev libncurses5-dev libreadline-dev zlib1g-dev &> /dev/null

        # Download and install lftp
        cd "$scriptdir/dependencies" || exit
        local lftpversion=$(curl -s https://github.com/lavv17/lftp/tags | grep -oP '(?<=tags/v)\d+\.\d+\.\d+' | sort -V | tail -n 1)
        wget "https://github.com/lavv17/lftp/archive/refs/tags/v$lftpversion.tar.gz" &> /dev/null
		mv "$scriptdir/dependencies/v$lftpversion.tar.gz" "$scriptdir/dependencies/lftp-$lftpversion.tar.gz"
        tar -xzvf "lftp-$lftpversion.tar.gz" &> /dev/null
        rm "$scriptdir/dependencies/lftp-$lftpversion.tar.gz"
        cd "lftp-$lftpversion" && ./configure --with-openssl --silent &> /dev/null && make --silent &> /dev/null && sudo checkinstall -y &> /dev/null

        # Check if lftp is installed
        echo -n " Checking for lftp ..."
        if [[ -n $(command -v lftp) ]]; then
            echo -e " \e[00;32m [Latest - v$lftpversion]\e[00m"
        else
            echo -e "INFO: Could not install program using sudo.\nYou have to install \"lftp\" manually... Exiting\n"
            exit 0
        fi
    fi
}

# Function to install/update lftp
function install_lftp {
    echo -n " Checking/updating lftp ..."

    # Check if lftp is installed
    if [[ -z $(command -v lftp) ]]; then
        # Prompt user to install lftp if not installed
        echo -e "lftp is not installed! It is required for FTPauto to work!"
        read -p " Do you want to install it (y/n)? "

        if [[ "$REPLY" == "y" ]]; then
            # Ask user for installation method
            read -p " Do you want latest version (needs to be compiled - SLOW - Any installed version will be removed) or the package from the repo (y/n)? "

            if [[ "$REPLY" == "y" ]]; then
                # Install lftp using latest version
                lftp_update install
            else
                # Install lftp from repository
                sudo apt-get -y install lftp &> /dev/null

                # Check if installation was successful
                if [[ $? -eq 1 ]]; then
                    echo "ERROR: Installation of lftp failed. Please install manually before continuing."
                    echo -e "... Exiting\n"
                    exit 1
                fi
            fi

            # Check if lftp is installed after installation
            echo -n "Checking lftp .."
            if [[ -z $(command -v lftp) ]]; then
                echo -e " \e[00;32m [OK]\e[00m"
            fi
        else
            # Inform user that FTPauto will not work without lftp and exit
            echo "FTPauto will not work without lftp. Exiting..."
            echo -e " Run install.sh uninstall to remove created files\n"
            exit 0
        fi
    else
        # Update lftp if it is already installed
        lftp_update
    fi
}

# Function to install/update rar2fs
function rar2fs_update {
	argument="$1"
	# Check if rar2fs is installed
	if [[ -n $(builtin type -p rar2fs) ]]; then
		# Get the current version of rar2fs
		local c_rar2fsversion=$(rar2fs --version 2> /dev/null | grep -Eo 'rar2fs\sv[0-9][0-9]?\.[0-9][0-9]?\.[0-9][0-9]?' | cut -d' ' -f2 | cut -d'v' -f2)
		# Get the latest release version of rar2fs from GitHub
		local rar2fsversion=$(curl -s https://api.github.com/repos/hasse69/rar2fs/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4 | cut -d '/' -f8 | cut -d'v' -f2)
		# Compare the versions
		version_compare "$rar2fsversion" "$c_rar2fsversion"
		if [[ "$new_version" == "true" ]]; then
			# Prompt user to update if a new version is available
			echo -e " [\e[00;33m$rar2fsversion available, current version $c_rar2fsversion\e[00m]"
			read -p " Do you wish to update(y/n)? "
			if [[ "$REPLY" == "y" ]]; then
				if [[ -n $(builtin type -p rar2fs) ]]; then
					# Remove old version and proceed with installation
					echo -n "Removing old version ..."
					sudo apt-get -y remove rar2fs &> /dev/null
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
	# Install rar2fs if specified or if it's not installed
	if [[ "$argument" == "install" ]]; then
		cd "$scriptdir/dependencies/"
		# Download and install rar2fs
		local var=$(curl -s https://api.github.com/repos/hasse69/rar2fs/releases | grep browser_download_url | head -n 1 | cut -d '"' -f 4)
		wget -q "$var"
		local name=$(basename "$var")
		tar zxf "$name" && rm "$name"
		name=${name::-7}
		cd "$name"
		wget -q https://www.rarlab.com/rar/unrarsrc-6.2.12.tar.gz && tar -zxf unrarsrc-6.2.12.tar.gz && rm unrarsrc-6.2.12.tar.gz
		cd unrar && make lib &> /dev/null && sudo make install-lib &> /dev/null && cd ..
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

# Function to install/update rar2fs
function install_rar2fs {
	echo -n " Checking/updating rar2fs ..."
	# Check if rar2fs is installed
	if [[ -z $(builtin type -p rar2fs) ]]; then
		echo -e "\n \"rar2fs\" is not installed! It is needed to mount rarfiles in order to send video files only. The file(s) will be transferred in original format otherwise"
		read -p " Do you want to install it(needs to be compiled - SLOW)(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			# Install required dependencies
			sudo apt-get -y install libfuse-dev autoconf &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\"\n... Exiting\n"
				exit 0
			else
				# Proceed with rar2fs installation
				rar2fs_update install
			fi
		else
			echo -e "Checking rar2fs ... [\e[00;33mSKIPPED\e[00m] NOTE: \"video\" will not work as send option"
		fi
	# If rar2fs is installed, check for updates
	elif [[ -n $(builtin type -p rar2fs) ]]; then
		rar2fs_update
	fi
}

# Function to install dependencies
function installDependencies {
	# Create necessary directories
	echo "Installing dependency tools ..."
	mkdir -p "$scriptdir/run" "$scriptdir/users"
	echo -n " Creating directories ..."
	echo -e "\e[00;32m [OK]\e[00m"

	# Check for existence of main files
	local main_files=("ftpauto.sh" "dependencies/transfer_main.sh" "dependencies/setup.sh" "dependencies/server_alive_test.sh" "dependencies/server_login.sh" "dependencies/server_list.sh" "dependencies/server_size_management.sh" "dependencies/help.sh" "plugins/largefile.sh" "dependencies/setup.sh" "dependencies/sorting.sh")
	for i in "${main_files[@]}"; do
		if [[ ! -f "$scriptdir/$i" ]]; then
			echo -e "\n\e[00;31m$i not found.\nScript will not work without... Try reinstalling it. Exiting...\e[00m\n"
			exit 1
		fi
	done
	echo -n " Checking files ..."
	echo -e "\e[00;32m [OK]\e[00m"

	# Install lftp
	install_lftp

	# Install optional tools
	echo "Installing optional tools ..."
	local programs=("rar" "cksfv")
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

	# Install rar2fs
	install_rar2fs

	# Prompt for user installation
	echo "Finalizing ..."
	read -p " Do you want to install a user? (You can add user later on)(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		read -p " What username do you want to use (leave empty for 'default')? "
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

# Function to handle installation
function install {
	# Prompt the user to confirm installation
	read -p "Do you wish to install? (y/n): "
	if [[ "$REPLY" == "n" ]]; then
		echo -e "... Exiting\n"
		exit 0
	fi

	# Install minimum required tools
	echo -e "\nInstalling minimum required tools ..."
	local programs=( "bc" "curl" "openssl" "date" "tail" "awk" "mkdir" "sed" "tput" "nano" "cut" "checkinstall")
	for i in "${programs[@]}"; do
		echo -n "Checking for $i ..."
		if [[ -z $(builtin type -p "$i") ]]; then
			echo -e "[Not found]"
			sudo apt-get -y install "$i" &> /dev/null
			if [[ $? -eq 1 ]]; then
				echo -e "INFO: Could not install program using sudo.\nYou have to install \"$i\"... Exiting\n"
				exit 0
			fi
			echo -n " Checking $i ..."
			if [[ -n $(builtin type -p "$i") ]]; then
				echo -e "[OK]"
			else
				echo -e "Script will not work without... exiting\n"
				exit 0
			fi
		else
			echo -e "[OK]"
		fi
	done

	# Update the script to the latest version
	updateScript installNew
	
	# Install dependencies
	installDependencies
}

# Function to uninstall FTPauto and its dependencies
function uninstall {
	# List of programs to be removed
	local programs=("lftp" "rar" "cksfv" "rar2fs" "pkg-config" "automake" "libfuse-dev" "checkinstall" "libssl-dev" "libncurses5-dev" "libreadline-dev" "zlib1g-dev" "autoconf")
	
	# Prompt the user to confirm uninstallation method
	echo "The following programs will be removed: ${programs[@]}"
	read -p "Do you want to remove all at once (y) or one by one (n)? (all=y/one-by-one(safe)=n): "
	
	# If user chooses to remove all at once
	if [[ "$REPLY" == "y" ]]; then
		# Confirm the user's intention to remove all programs
		read -p "WARNING: THIS WILL REMOVE ALL PROGRAMS. ARE YOU SURE? (y/n): "
		if [[ "$REPLY" == "y" ]]; then
			# Remove all programs
			for i in "${programs[@]}"; do
				sudo apt-get -y remove "$i" &> /dev/null
				echo -e "$i [REMOVED]"
			done
		fi
	else
		# If user chooses to remove one by one
		for i in "${programs[@]}"; do
			# Check if program exists before attempting to remove it
			if builtin type -p "$i" &>/dev/null; then
				echo -n "Removing $i ..."
				# Prompt the user to confirm removal of each program
				read -p "Do you want to remove it? (y/n): "
				if [[ "$REPLY" == "y" ]]; then
					sudo apt-get -y remove "$i" &> /dev/null
					echo -e "[REMOVED]"
				else
					echo -e "[KEPT]"
				fi
			fi
		done
	fi
	
	# Remove FTPauto and its dependencies
	echo -n "Removing source files ..."
	sudo rm -rf "$scriptdir/dependencies/" "$scriptdir/plugins/"
	rm -f "$scriptdir/ftpauto.sh" "$scriptdir/LICENCE" "$scriptdir/README.md" "$scriptdir/ftpauto.sh"
	echo -e "[OK]"
	
	echo -n "Removing user files ..."
	rm -rf "$scriptdir/run" "$scriptdir/users"
	
	echo -n "Removing remainder of FTPauto ..."
	rm -rf "$scriptdir"	
	
	# Inform user of successful removal
	echo -e "[OK]\nComplete removal of FTPauto and dependencies!\n"
	exit 0
}

# Function to handle downloading the script
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

# Function to handle updating the script
function updateScript {
	argument="$1"
	getCurrentVersion
	echo -n " Checking/updating FTPauto ..."
	local release_version=$(curl -s https://api.github.com/repos/Meliox/ftpauto/tags | grep -oP '"name": "\KFTPauto-v\d+\.\d+\.\d+' | sort -V | tail -n 1 | cut -d'v' -f2)
	version_compare "$release_version" "$i_version"
	if [[ "$i_version" == "0" ]] && [[ $argument != installNew ]]; then
		echo -e "\e[00;31m [ERROR]\e[00m\nNo installation found. Execute script with install as argument instead. Exiting.\n"
		exit 0
	elif [[ "$new_version" == "true" ]] && [[ $argument == installNew ]]; then
		echo -e "\e[00;32m [Found - v$release_version]\e[00m"
		read -p " Do you wish to update(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			downloadScript
		else
			echo -e " FTPauto update ... [\e[00;33mSKIPPED\e[00m]"
		fi
	elif [[ "$new_version" == "true" ]] && [[ $argument != installNew ]]; then
		echo -e "\e[00;33m [Found - v$release_version]\e[00m"
		read -p " Do you wish to update(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			downloadScript
		else
			echo -e " FTPauto update ... [\e[00;33mSKIPPED\e[00m]"
		fi
	else
		if [[ "$argument" == "installNew" ]]; then
			echo -e " \e[00;32m[Local - v$i_version, Latest - v$release_version]\e[00m"
		else
			echo -e " \e[00;32m [Local - v$i_version, Latest - v$i_version]\e[00m"
		fi
	fi
}

case "$1" in
	installNew)
		updateScript installNew
		;;
	install)
		install
		;;
	uninstall)
		uninstall
		;;
	*)
		echo "Usage: $0 {install|uninstall}" >&2
		exit 1
		;;
esac