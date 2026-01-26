#!/usr/bin/env bash
#
# Script Name: App Staged Install with Jamf Helper
# Description:
#   Waits for Self Service to launch, then shows full-screen jamfHelper
#   splash screens while sequentially triggering Jamf policies to install
#   core apps and apply basic settings.
#

set -euo pipefail

readonly JAMFHELPER="/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper"

wait_for_self_service() {
  local setup_process=""

  while [[ -z "${setup_process}" ]]; do
    echo "Waiting for Self Service…"
    setup_process="$(/usr/bin/pgrep 'Self Service' || true)"
    sleep 3
  done

  echo "Self Service detected; continuing."
}

show_fullscreen_icon_and_run() {
  local icon_path="$1"
  shift
  local cmd=("$@")

  "${JAMFHELPER}" \
    -windowType fs \
    -icon "${icon_path}" \
    -fullScreenIcon &

  # Run associated command in foreground
  "${cmd[@]}"
}

main() {
  wait_for_self_service

  # Initial splash
  "${JAMFHELPER}" \
    -windowType fs \
    -icon "/Library/Application Support/SideIT/initiatingSetup.png" \
    -fullScreenIcon &
  sleep 5

  # Chrome
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/chrome.png" \
    sudo /usr/local/bin/jamf policy -event googlechrome

  # Drive
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/drive.png" \
    sudo /usr/local/bin/jamf policy -event googledrive

  # Slack
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/slack.png" \
    sudo /usr/local/bin/jamf policy -event slack

  # Zoom + initial Dock set
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/zoom.png" \
    bash -c 'sudo /usr/local/bin/jamf policy -event zoominfo; sudo /usr/local/bin/jamf policy -event modifyDock'

  # inSiderIntranet
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/intranet.png" \
    sudo /usr/local/bin/jamf policy -event inSiderIntranet

  # Machine name
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/settings1.png" \
    sudo /usr/local/bin/jamf policy -event mbpname

  # User upload
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/settings2.png" \
    sudo /usr/local/bin/jamf policy -event uploadUser

  sleep 3

  # Dock adjustments
  show_fullscreen_icon_and_run \
    "/Library/Application Support/SideIT/settings3.png" \
    sudo /usr/local/bin/jamf policy -event modifyDock

  # FileVault enable reminder
  "${JAMFHELPER}" \
    -windowType fs \
    -icon "/Library/Application Support/SideIT/filevaultenable.png" \
    -fullScreenIcon &
  sleep 5

  # Close Self Service before reboot or handoff
  killall "Self Service" 2>/dev/null || true
}

main "$@"



-------OG
#!/bin/sh

# wait until the Self Service process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Self Service..."
	setupProcess=$( /usr/bin/pgrep "Self Service" )
	sleep 3
done


#intialiaizng
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/initiatingSetup.png -fullScreenIcon & sleep 5


#chrome
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/chrome.png -fullScreenIcon & sudo jamf policy -event googlechrome

#drive
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/drive.png -fullScreenIcon & sudo jamf policy -event googledrive

#slack
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/slack.png -fullScreenIcon & sudo jamf policy -event slack

#zoom & set dock (first run)
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/zoom.png -fullScreenIcon & sudo jamf policy -event zoominfo; sudo jamf policy -event modifyDock

#settings > inSiderIntranet App
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/intranet.png -fullScreenIcon & sudo jamf policy -event inSiderIntranet




#settings > machine name
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings1.png -fullScreenIcon & sudo jamf policy -event mbpname

#settings > user fill
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings2.png -fullScreenIcon & sudo jamf policy -event uploadUser


#small break
sleep 3

#settings > dock
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings3.png -fullScreenIcon & sudo jamf policy -event modifyDock

#settings > filevault login alert
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/filevaultenable.png -fullScreenIcon & sleep 5

#close self service before rebooting
killall Self\ Service
