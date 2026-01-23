#!/usr/bin/env bash
#
# Script Name: Jamf Recon with RealName Username
# Description:
#   Derives a friendly username from the current console user’s RealName,
#   waits until the user is no longer “System Administrator”, then runs
#   Jamf recon (optionally against a specified LDAP server).
#

set -euo pipefail

get_user_info() {
  local console_user real_name lower_name no_spaces dotted

  console_user="$(stat -f '%Su' /dev/console)"
  real_name="$(dscl . -read "/Users/${console_user}" RealName 2>/dev/null \
    | cut -d':' -f2- \
    | sed -e 's/^[[:space:]]*//' \
    | grep -v '^$' || true)"

  echo "Console user: ${console_user}"
  echo "Full name: ${real_name}"

  lower_name="$(echo "${real_name}" | tr '[:upper:]' '[:lower:]')"
  echo "Full name lowercase: ${lower_name}"

  no_spaces="${lower_name//[[:blank:]]/}"
  echo "User name (no spaces): ${no_spaces}"

  dotted="${lower_name// /.}"
  echo "User name with dot: ${dotted}"

  derived_email="${dotted}@side.com"
  full_name="${real_name}"
  lowered_full_name="${lower_name}"
}

main() {
  local count=0
  local ldap_server="${3:-}"

  get_user_info
  echo "Checking username…"
  echo "Count: ${count}"

  # Wait until full name is not “system administrator”
  while [[ "${lowered_full_name}" == "system administrator" ]]; do
    echo "User is System Administrator; waiting…"
    count=$((count + 1))
    echo "Sleep 10 x ${count}"
    sleep 10

    # Run recon tagged as sysadmin on first detection
    if [[ "${count}" -eq 1 ]]; then
      echo "Tagging inventory as sysadmin (first detection)."
      sudo /usr/local/bin/jamf recon -room "sysadmin"
    fi

    # After a minute (6 x 10s), bail out if still System Administrator
    if [[ "${count}" -ge 6 ]]; then
      echo "After ~1 minute, System Administrator is still the user; tagging and exiting."
      sudo /usr/local/bin/jamf recon -room "sysadmin"
      exit 0
    fi

    # Refresh user info after sleep
    get_user_info
  done

  echo "User found (${full_name}), running recon."

  # If you want to use the derived email in the future, you can pass it as endUsername.
  # For now, this keeps your original behavior.
  if [[ -n "${ldap_server}" ]]; then
    sudo /usr/local/bin/jamf recon -ldapServer "${ldap_server}"
  else
    sudo /usr/local/bin/jamf recon
  fi
}

main "$@"




--------OG
#!/bin/bash

getUserName () {
usernamepull="$(stat -f%Su /dev/console)"
fullName="$(dscl . -read /Users/$usernamepull RealName | cut -d: -f2 | sed -e 's/^[ \t]*//' | grep -v "^$")"
echo "Full name: "$fullName

lowerCase=$(echo $fullName | tr "[:upper:]" "[:lower:]")
echo "Full name lowercase: "$lowerCase

userName=${lowerCase//[[:blank:]]/}
echo "User Name: "$userName

#replace space with period
replaceSpace=${lowerCase// /.}
echo "Turn space into period: "$replaceSpace

#email=${replaceSpace}@side.com
#echo $email
}

getUserName
echo "Checking Username"

let count=1
echo "Coount: "$count

while [ "$lowerCase" = "system administrator" ];
do
	echo "User is system administrator"
	getUserName
    
	let count=$count+1
    echo "Sleep 10 x "$count
	sleep 10
	
	if [ $count == 1 ]; then
		sudo jamf recon -room "sysadmin"
	elif [ $count == 6 ]; then
		echo "After a minute of attempting, system administrator is still the user, running recon and exiting"
		sudo jamf recon -room "sysadmin"
		exit 0
	fi
	
done
echo "User found, running recon"

#sudo jamf recon -endUsername "$email" -ldapServer $3

#sudo jamf recon -endUsername $replaceSpace -ldapServer $3

sudo jamf recon -ldapServer $3
