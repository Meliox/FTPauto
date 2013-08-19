#!/bin/bash
export LC_ALL=C

# Filename ($1)
# Results go into global associative array ben
declare -A ben
benparse() {
  local data skip p max
  [[ -r $1 ]] || { echo "cannot read file '$1'"; return 1; }
  IFS= read -rd '' data < <(tr \\0 \\1 <"$1")
  max=${#data}

  # Begin parsing file at offset 0, namespace ""
  bp_parse 0 ""
}

# Starting offset ($1), starting namespace ($2)
# Uses global AA ben, module variable data
# Return parsed data in module var p
# Return total char length of parsed data in module var skip
bp_parse() {
  (($1 >= max)) && return
  case "${data:$1:1}" in
  d)
    # Data dictionary, terminated by "e".  Get pairs.
    local i=$1 j=$(($1 + 1)) key value
    while ((j < max)) && [[ ${data:j:1} != e ]]; do
      bp_parse $j "$2."
      key=$p
      ((j+=skip))
      bp_parse $j "$2.$key"
      value=$p
      ((j+=skip))
      [[ $value ]] && ben["$2.$key"]=$value
    done
    p=""        # We populate the AA ourselves, rather than passing data back
    skip=$((j-i+1))
    ;;
  i)
    # Integer, terminated by "e"
    local i=$1 j=$(($1 + 1))
    while [[ ${data:j:1} != e ]]; do
      ((j++))
    done
    p=${data:i+1:j-i-1}
    skip=$((j-i+1))
    ;;
  l)
    # List, concatenated elements, terminated by "e"
    local i=$1 j=$(($1 + 1)) k=0 value
    while [[ ${data:j:1} != e ]]; do
      bp_parse $j "$2.$k"
      [[ $p ]] && ben["$2.$k"]=$p
      ((k++, j+=skip))
    done
    p=""
    skip=$((j-i+1))
    ;;
  *)
    # String, length-prefixed (integer, colon).  Get the length first.
    local n n_len
    bp_getnum $1
    n_len=${#n}
    p=${data:$1+n_len+1:n}
    skip=$((n_len+1+n))
    ;;
  esac
}

# Find an integer in data, beginning at offset ($1)
# Return value in upstream variable n
bp_getnum() {
  local i=$1 j=$1
  while [[ ${data:j:1} = [[:digit:]-] ]]; do
    ((j++))
  done
  n=${data:i:j-i}
}

benparse "$1"
# Dump the AA, indices in string-sorted order
# Skip the big binary blob
printf "%s\n" "${!ben[@]}" | sort | while IFS= read -r idx; do
  ((${#ben["$idx"]} > 80)) && continue
  printf "%-24.24s %s\n" "$idx:" "${ben["$idx"]}"
done
