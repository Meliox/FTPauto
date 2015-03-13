#!/bin/bash
#Shell-script wrapper around curl for sending messages through PushOver
#For more info, see https://pushover.net/
version="1.1"
rev=1
message="$1"
#send message through curl
CURL="$(which curl)"
PUSHOVER_URL="https://api.pushover.net/1/messages"
if [[ -n "$push_token" ]] && [[ -n "$push_user" ]] && [[ -n "$message" ]]; then
	echo "INFO: Sending pushnotification"
	curl_cmd="\"${CURL}\" -s \
	   -F \"token=${push_token}\" \
	   -F \"user=${push_user}\" \
	   -F \"message=${message}\" \
	   ${PUSHOVER_URL} 2>&1 >/dev/null || echo \"$0: Failed to send message\" >&2"
	eval "${curl_cmd}"
	echo "INFO: Pushnotification sent"
else
	echo -e "\e[00;31mERROR: All settings are not set.\e[00m"
fi
