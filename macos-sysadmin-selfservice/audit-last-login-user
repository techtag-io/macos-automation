#!/usr/bin/env bash
#
# Script Name: Track Last Logged-In User
# Description:
#   Records the last non-root console user in /Library/loginuser.txt
#   and triggers Jamf user upload only when the user changes.
#

set -euo pipefail

readonly LOG_FILE="/Library/loginuser.txt"

get_console_user() {
  stat -f '%Su' /dev/console
}

main() {
  local last_user rec_login

  last_user="$(get_console_user)"
  echo "Initial console user: ${last_user}"

  # Wait until console user is not root
  while [[ "${last_user}" == "root" ]]; do
    echo "Console user is root; waiting 5 seconds… (current: ${last_user})"
    sleep 5
    last_user="$(get_console_user)"
  done

  echo "${last_user} is not root, proceeding…"
  echo "Checking for ${LOG_FILE}"

  # If file does not exist, create it with current user and exit
  if [[ ! -f "${LOG_FILE}" ]]; then
    echo "File not found; creating with current user."
    # Use tee with sudo to avoid issues with redirection as root
    printf '%s\n' "${last_user}" | sudo tee "${LOG_FILE}" >/dev/null
    echo "No prior user recorded; exiting."
    exit 0
  fi

  # File exists: get last recorded user
  rec_login="$(tail -n 1 "${LOG_FILE}")"
  echo "Recorded last login user from file: ${rec_login}"

  if [[ "${last_user}" == "${rec_login}" ]]; then
    echo "Current user (${last_user}) matches recorded user (${rec_login}); nothing to do. Exiting."
    exit 0
  fi

  # New user detected: append and run Jamf tasks
  printf '%s\n' "${last_user}" | sudo tee -a "${LOG_FILE}" >/dev/null
  echo "New user detected (${last_user} != ${rec_login}); running Jamf user upload."

  sudo /usr/local/bin/jamf policy -event uploadUser
  /usr/local/bin/jamf recon -room "Check User"

  exit 0
}

main "$@"



-------OG
#!/bin/sh

#Get last user from text file
LASTUSER="$(stat -f%Su /dev/console)"
echo "first pull: $LASTUSER"

#set Dir parameter
LogDir='/Library/loginuser.txt'

#until the user account is not root, loop the script
until [ "$LASTUSER" != "root" ]
do 

echo "waiting for LASTUSER... Sleep 5: $LASTUSER"
sleep 5

done

echo "$LASTUSER is not root, proceeding..."
echo "Checking for $LogDir"

#Does text file exist?

#if [[ -f /Library/loginuser.txt ]]; then
if [[ -f $LogDir ]]; then

	#yes - pull last name
	echo "File exists, skipping creation of file..."
	
else
	
	#no - create it and put in current name
	echo "Creating file with last user..."
	sudo echo $LASTUSER >> $LogDir
    echo "No need to push, exiting script"
    exit 0

	
fi

#Pull last user
RECLOGIN=$( tail -n 1 $LogDir )
echo "$RECLOGIN pulled from file"


####### Matching

if [ "$LASTUSER" == "$RECLOGIN" ]; then
	echo "$LASTUSER = $RECLOGIN , skipping and exiting"
    exit 0
    
    #script alert
#osascript <<EOF 

#display dialog "SAME USER!" with title "SAME USER!" buttons ("OK!")

#EOF
    
    
	exit 0
else
	echo $LASTUSER >> $LogDir
	echo "$LASTUSER != $RECLOGIN ... run stuff"
    sudo jamf policy -event uploadUser
    /usr/local/bin/jamf recon -room "Check User"
    exit 0
    
        #script alert
#osascript <<EOF 

#display dialog "NEW USER!" with title "NEW USER!" buttons ("OK!")

#EOF
	
fi
