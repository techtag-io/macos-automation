#!/usr/bin/env bash
#
# Script Name: Wait for Dock, then Trigger Jamf Setup
# Description:
#   Waits until the Dock process is running (user session ready),
#   then triggers the Jamf policy `jamfHelperSetup`.
#

set -euo pipefail

main() {
  local setup_process=""

  # Wait until Dock has started (indicates user session is up)
  while [[ -z "${setup_process}" ]]; do
    echo "Waiting for Dock…"
    setup_process="$(/usr/bin/pgrep 'Dock' || true)"
    sleep 3
  done

  echo "Dock detected; triggering Jamf setup policy."
  sudo /usr/local/bin/jamf policy -event jamfHelperSetup
}

main "$@"



-----OG
#!/bin/sh

# wait until the Dock process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Dock"
	setupProcess=$( /usr/bin/pgrep "Dock" )
	sleep 3
done

sleep 3

#trigger policy
sudo jamf policy -event jamfHelperSetup
