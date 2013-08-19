#!/bin/bash
function flexget_feed {
# if feed if coming from flexget and it comes from $feed_name remove it
	if [[ -n "$feed_name" ]]; then
		if [[ "$feed" == "$feed_name" ]] && [[ -n "$feed_name" ]]; then
			sed /"$orig_name"/d -i "$c_flexget"
		fi
	fi
}



	