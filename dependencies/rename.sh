#!/bin/bash
# Version 0.1

# Renames the transferred item, and the files and folders inside it, on the destination.
# The source is never modified. Rules are defined in the user config as rename_array, each rule being
#   "<path glob>|<name glob>|<sed expression>"
# path glob       : must be found in the source path. Empty matches any path
# name glob       : must match the name of the transferred item. Empty matches any name
# sed expression  : applied with sed -E to the item name and to every file/folder name inside it
# The first rule matching both globs is used. Example:
#   rename_array=( "TV-DANISH|Frank.Og.Kastaniegaarden.*|s/\.S19E/.S2026E/" )

# Selects the first matching rule and stores its sed expression in rename_expr
function rename_select {
	local rule rest path_glob name_glob

	rename_expr=""
	for rule in "${rename_array[@]}"; do
		[[ -z "$rule" ]] && continue
		if [[ "$rule" != *"|"*"|"* ]]; then
			echo -e "\e[00;33mINFO: Ignoring invalid rename rule, expected \"<path glob>|<name glob>|<sed expression>\": $rule\e[00m"
			continue
		fi
		path_glob="${rule%%|*}"
		rest="${rule#*|}"
		name_glob="${rest%%|*}"
		[[ -n "$path_glob" && "$filepath" != *$path_glob* ]] && continue
		[[ -n "$name_glob" && "$orig_name" != $name_glob ]] && continue
		rename_expr="${rest#*|}"
		return 0
	done
	return 1
}

# Prints $1 renamed with the selected rule. Prints $1 unchanged if the rule fails or gives an unusable name
function rename_name {
	local new

	new=$(printf '%s' "$1" | sed -E "$rename_expr" 2>/dev/null)
	if [[ $? -ne 0 || -z "$new" || "$new" == */* ]]; then
		printf '%s' "$1"
	else
		printf '%s' "$new"
	fi
}

# Prints the relative path $1 with every path component renamed
function rename_path {
	local -a parts new_parts
	local part IFS=/

	read -ra parts <<< "$1"
	for part in "${parts[@]}"; do
		new_parts+=("$(rename_name "$part")")
	done
	printf '%s' "${new_parts[*]}"
}

# Returns 0 if the name contains characters that cannot be safely passed to a shell command
function rename_unsafe {
	case "$1" in
		*\"*|*\$*|*\`*|*\\*) return 0;;
	esac
	return 1
}

# Fills rename_items with the paths of everything inside the source item, relative to the item
function rename_collect {
	local line prefix="${transfer_path%/}/"

	rename_items=()
	if [[ "$transferetype" == "downftp" || "$transferetype" == "fxp" ]]; then
		# Source is on the server
		[[ "$transfer_type" == "directory" ]] || return 0
		{ cat "$login_file1"; echo "find \"$transfer_path\""; echo "quit"; } > "$transfere_file.list"
		while IFS= read -r line; do
			line="${line%/}"
			[[ "$line" == "$prefix"* ]] && rename_items+=("${line#"$prefix"}")
		done < <("$lftp" -f "$transfere_file.list" 2>/dev/null)
		rm -f "$transfere_file.list"
		[[ ${#rename_items[@]} -eq 0 ]] && echo -e "\e[00;33mINFO: Could not list the content of $transfer_path. Only the name of the item itself is renamed\e[00m"
	else
		[[ -d "$transfer_path" ]] || return 0
		while IFS= read -r -d '' line; do
			rename_items+=("$line")
		done < <(cd "$transfer_path" && find -L . -mindepth 1 -printf '%P\0')
	fi
}

# Local source: builds a folder of symbolic links using the new names. This is transferred instead of the source
function rename_stage {
	local stage="$scriptdir/run/$username-temp/${orig_name}-stage/" rel new_rel src

	src=$(readlink -f "$transfer_path")
	rm -rf "$stage"
	if [[ -d "$transfer_path" ]]; then
		mkdir -p "$stage$dest_name"
		rename_collect
		for rel in "${rename_items[@]}"; do
			new_rel=$(rename_path "$rel")
			if [[ -d "$transfer_path/$rel" ]]; then
				mkdir -p "$stage$dest_name/$new_rel"
			else
				mkdir -p "$(dirname "$stage$dest_name/$new_rel")"
				ln -s "$src/$rel" "$stage$dest_name/$new_rel"
			fi
		done
	else
		mkdir -p "$stage"
		ln -s "$src" "$stage$dest_name"
	fi
	transfer_path="$stage$dest_name"
}

# Server source: appends lftp commands to the transfer file that rename everything inside $1 on the destination.
# The deepest paths are renamed first, so the parent paths are still unchanged when they are used
function rename_destination_commands {
	local root="$1" rel parent old new

	rename_collect
	while IFS= read -r rel; do
		[[ -z "$rel" ]] && continue
		parent=""
		[[ "$rel" == */* ]] && parent="${rel%/*}/"
		old="${rel##*/}"
		new=$(rename_name "$old")
		[[ "$new" == "$old" ]] && continue
		if rename_unsafe "$root/$parent$old" || rename_unsafe "$new"; then
			echo -e "\e[00;33mINFO: Not renaming \"$parent$old\" as the name contains unsupported characters\e[00m"
			continue
		fi
		if [[ "$transferetype" == "downftp" ]]; then
			echo "!mv -f -- \"$root/$parent$old\" \"$root/$parent$new\"" >> "$transfere_file"
		else
			echo "mv \"$root/$parent$old\" \"$root/$parent$new\"" >> "$transfere_file"
		fi
	done < <(printf '%s\n' "${rename_items[@]}" | awk -F/ '{print NF "\t" $0}' | sort -t "$(printf '\t')" -k1,1nr | cut -f2-)
}

# Sets dest_name and prepares the transfer. Called after dest_name has been initialised with orig_name
function rename_resolve {
	[[ ${#rename_array[@]} -eq 0 ]] && return 0

	if [[ "$send_option" != "default" ]]; then
		echo "INFO: Renaming is only supported with send_option=default. Skipping"
		return 0
	fi

	rename_select || return 0
	if rename_unsafe "$orig_name"; then
		echo -e "\e[00;33mINFO: Not renaming \"$orig_name\" as the name contains unsupported characters\e[00m"
		return 0
	fi
	dest_name=$(rename_name "$orig_name")
	if rename_unsafe "$dest_name"; then
		echo -e "\e[00;33mINFO: Not renaming to \"$dest_name\" as the name contains unsupported characters\e[00m"
		dest_name="$orig_name"
		return 0
	fi
	rename_active="true"
	if [[ "$dest_name" == "$orig_name" ]]; then
		echo "INFO: Rename rule matched, but the name is unchanged: $orig_name"
	else
		echo -e "\e[00;37mINFO: Rename: \e[00;32m$orig_name -> $dest_name\e[00m"
	fi

	# A local source cannot be renamed, so a copy with links using the new names is transferred
	if [[ "$transferetype" == "upftp" || "$transferetype" == "upsftp" ]]; then
		rename_stage
	fi
}
