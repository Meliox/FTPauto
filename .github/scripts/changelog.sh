#!/bin/bash
# Usage: changelog.sh <previous_tag|""> <new_version> [ref]
# Prints a markdown changelog of commits between <previous_tag> and [ref] (default HEAD).
set -euo pipefail

prev_tag="${1:-}"
new_version="${2:?new version required}"
ref="${3:-HEAD}"

if [[ -n "$prev_tag" ]]; then
	range="${prev_tag}..${ref}"
else
	range="$ref"
fi

mapfile -t subjects < <(git log --no-merges --pretty=format:'%s (%h)' "$range")

features=() fixes=() others=()
for s in "${subjects[@]}"; do
	[[ -z "$s" ]] && continue
	# Subjects look like "(feat): text", "(fix) text", "feat: text"
	if [[ "$s" =~ ^\(?(feat|feature)\)?(:|[[:space:]]) ]]; then
		features+=("${s#*[[:space:]]}")
	elif [[ "$s" =~ ^\(?(fix|bugfix|hotfix)\)?(:|[[:space:]]) ]]; then
		fixes+=("${s#*[[:space:]]}")
	else
		others+=("$s")
	fi
done

section() {
	local title="$1"; shift
	[[ $# -eq 0 ]] && return
	printf '\n### %s\n\n' "$title"
	printf -- '- %s\n' "$@"
}

printf '## v%s - %s\n' "$new_version" "$(date -u +%Y-%m-%d)"
section "Features" "${features[@]}"
section "Fixes" "${fixes[@]}"
section "Other changes" "${others[@]}"
if [[ ${#subjects[@]} -eq 0 ]]; then
	printf '\nNo changes.\n'
fi
