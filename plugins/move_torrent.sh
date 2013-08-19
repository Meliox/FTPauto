#!/bin/bash
OLDIFS=$IFS
IFS=$(echo -en "\n\b")
version="3.1"
downloaddir="/home/ammin/rtorrent/watchdir-melior/"
movetodir="/home/ammin/rtorrent/watchdir-highdefinition/"
scriptdir="$(dirname $(readlink -f $0))"
torrentfiles="$(find $downloaddir -name '*.torrent')"
parse_torrent_script=""$scriptdir"/parse_torrent.sh"
flexgetconfig="/home/ammin/flexget-download/download.yml"

function show_help {
	echo "Torrent helper - $version"
	echo
	echo "Arguments allowed:"
	echo "--input_path=/some/torrent/download/path/" 
	echo "--output_path=/where/to/move/torrent/files/"
	echo "--flexget_config=~/flexget/download.xml path to flexget config"
	echo "--help shows help"
	echo "--verbose debug option"
	echo "--auto move torrents with defined values in move_torrent.sh"
	echo "--info=~/test.torrent prints info from torrent file"
	echo
}

function parse_torrent {
	echo
	echo "Printing torrent info:"
	bash "$parse_torrent_script" "$torrent_file"
	echo
}

function auto_run {
	echo "Using autorun. Using values definied in move_torrent.sh"
	if ((verbose)); then set -x; fi
	if [ ! -f "$parse_torrent_script" ]; then echo "ERROR: parse_torrent.sh is missing"; exit 1; fi;
	if [ ! -f "$flexgetconfig" ]; then echo "ERROR: flexget config could not be found at $flexgetconfig"; exit 1; fi;
	if [ -z "$torrentfiles" ]; then echo "No torrents in $downloaddir, exiting"; exit 0; fi
	echo "Found these torrent(s): $torrentfiles"
	for f in $torrentfiles; do
	        filename=$(basename $f)
	        path=$(bash "$parse_torrent_script" "$f" | grep info.name | sed "s/.* [^:] //")
	        echo "Adding $path to $flexgetconfig"
	        echo "        - $path" >> $flexgetconfig
	        echo "Moving $path to $movetodir"
	        mv "$f" "$movetodir""$filename"
	done
}


if (($# < 1 )); then echo "ERROR: No option specified"; show_help; exit 3; fi
echo "Torrent helper - $version"
while :
do
        case "$1" in
                --help | -h ) show_help; exit 1;;
                --verbose | -v) verbose=1; shift;;
                --input_path ) if (($# > 1 )); then input_path=$2; else echo "Invalid option for argument '$@'"; show_help; exit 1; fi; shift 2;;
                --input_path=* ) input_path=${1#--input_path=}; shift;;
                --output_path ) if (($# > 1 )); then output_path=$2; else echo "Invalid option for argument '$@'"; show_help; exit 1; fi; shift 2;;
                --output_path=* ) output_path=${1#--output_path=}; shift;;
                --flexget_config ) if (($# > 1 )); then flexget_config=$2; else echo "Invalid option for argument '$@'"; show_help; exit 1; fi; shift 2;;
                --flexget_config=* ) flexget_config=${1#--flexget_config=}; shift;;
		--info=* ) torrent_file=${1#--info=}; parse_torrent; exit 0;;
		--info ) if (($# > 1 )); then torrent_file=$2; parse_torrent; exit 0; else echo "Invalid option for argument '$@'"; exit 1; fi;;
		--auto ) auto_run; exit 0;;
                -* ) echo "Invalid option: $@"; show_help; exit 1;;
                * ) break ;;
                --) shift; break;;
        esac
done
#Manuel way

if ((verbose)); then set -x; fi

if [ ! -d "$input_path" ]; then echo "ERROR: Option --input_path is required with existing path"; show_help; exit 3; fi
if [ ! -d "$output_path" ]; then echo "ERROR: Option --output_path is required with existing path"; show_help; exit 3; fi
if [ ! -f "$flexget_config" ]; then echo "ERROR: Option --output_path is required with existing path"; show_help; exit 3; fi

#torrent_files="$(find $input_path -name '*.torrent')"
echo "Found these torrent(s): $torrent_files"

for f in "$torrent_files"; do
	filename=$(basename "$f" )
	path=$(bash "$parse_torrent_script" "$f" | grep info.name | sed "s/.* [^:] //")
	echo "Adding $path to $flexget_config"
	echo "        - $path" >> $flexget_config
	echo "Moving $path to $output_dir"
	mv "$f" "$movetodir""$filename"
done
IFS=$SAVEIFS
exit 0
