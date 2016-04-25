#!/bin/bash
#Shell-script wrapper around curl for sending messages through PushOver
#For more info, see https://pushover.net/
function Pushover {
version="1.2"
push_title="NEW: $1"
push_message="$2"
#send message through curl
CURL="$(which curl)"
PUSHOVER_URL="https://api.pushover.net/1/messages"
if [[ -n "$push_token" ]] && [[ -n "$push_user" ]] && [[ -n "$push_message" ]]; then
	echo "INFO: Sending push-notification"
	curl_cmd="\"${CURL}\" -s \
	   -F \"token=${push_token}\" \
	   -F \"user=${push_user}\" \
	   -F \"title=${push_title}\" \
	   -F \"message=${push_message}\" \
	   ${PUSHOVER_URL} 2>&1 >/dev/null || echo \"$0: Failed to send message\" >&2"
	eval "${curl_cmd}"
	echo "INFO: Push-notification sent"
else
	echo -e "\e[00;31mERROR: All settings are not set.\e[00m"
fi
}