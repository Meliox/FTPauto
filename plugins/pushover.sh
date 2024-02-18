#!/bin/bash

# Shell-script wrapper around curl for sending messages through PushOver
# For more info, see https://pushover.net/
function Pushover {
	# Function to send a message through PushOver

	# Version of the script
	version="1.2"

	# Extract parameters
	push_title="$1"
	push_message="$2"

	# Find the location of curl
	CURL="$(which curl)"

	# PushOver API URL
	PUSHOVER_URL="https://api.pushover.net/1/messages"

	# Check if all necessary parameters are provided
	if [[ -n "$push_token" ]] && [[ -n "$push_user" ]] && [[ -n "$push_message" ]]; then
		# If all parameters are provided, send the push notification
		echo "INFO: Sending push-notification"
		# Construct the curl command
		curl_cmd="\"${CURL}\" -s \
			-F \"token=${push_token}\" \
			-F \"user=${push_user}\" \
			-F \"title=${push_title}\" \
			-F \"message=${push_message}\" \
			${PUSHOVER_URL} 2>&1 >/dev/null || echo \"$0: Failed to send message\" >&2"
		# Execute the curl command
		eval "${curl_cmd}"
		echo "INFO: Push-notification sent"
	else
		# If any of the parameters are missing, display an error message
		echo -e "\e[00;31mERROR: All settings are not set.\e[00m"
	fi
}
