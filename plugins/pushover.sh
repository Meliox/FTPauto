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
		# Values are passed as arguments (not through eval) as they contain file names
		if "$CURL" -s --fail \
			--form-string "token=${push_token}" \
			--form-string "user=${push_user}" \
			--form-string "title=${push_title}" \
			--form-string "message=${push_message}" \
			"${PUSHOVER_URL}" > /dev/null 2>&1; then
			echo "INFO: Push-notification sent"
		else
			echo -e "\e[00;31mERROR: Failed to send push-notification\e[00m" >&2
		fi
	else
		# If any of the parameters are missing, display an error message
		echo -e "\e[00;31mERROR: All settings are not set.\e[00m"
	fi
}
