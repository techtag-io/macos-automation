
#!/usr/bin/env bash
#
# Script Name: Reinstall Slack (macOS)
# Description:
#   Gracefully closes Slack, removes the existing app bundle,
#   downloads the latest Slack DMG, installs to /Applications,
#   then relaunches Slack.
#

set -euo pipefail

main() {
  local dmg_file="/tmp/Slack.dmg"
  local final_url
  local mount_point

  echo "Closing Slack if running…"
  killall "Slack" 2>/dev/null || true

  echo "Removing existing Slack.app from /Applications…"
  sudo rm -rf "/Applications/Slack.app"

  echo "Resolving latest Slack download URL…"
  final_url="$(
    curl "https://slack.com/ssb/download-osx" \
      -s -L -I -o /dev/null -w '%{url_effective}'
  )"

  echo "Downloading Slack from: ${final_url}"
  sudo /usr/bin/curl --retry 3 -L "${final_url}" -o "${dmg_file}"

  echo "Mounting DMG…"
  /usr/bin/hdiutil attach "${dmg_file}" -nobrowse -quiet

  echo "Copying Slack.app to /Applications…"
  ditto -rsrc "/Volumes/Slack/Slack.app" "/Applications/Slack.app"

  echo "Sleeping 3 seconds…"
  sleep 3

  echo "Unmounting DMG…"
  /usr/bin/hdiutil detach "$(/bin/df | /usr/bin/grep 'Slack' | awk '{print $1}')" -quiet || true

  echo "Cleaning up temporary DMG…"
  sudo rm -f "${dmg_file}"

  echo "Opening Slack…"
  open "/Applications/Slack.app"

  echo "Done."
  exit 0
}

main "$@"



------OG
#!/bin/bash

#get username
#userName=$(whoami)
#echo "username is: "$userName

#close Slack
killall Slack

#fix helper
#sudo chown -R $userName:staff /Applications/Slack.app


#### remove and reinstall
sudo rm -rf /Applications/Slack.app

#set directories
echo "Setting directories..."
finalURL=$(curl https://slack.com/ssb/download-osx -s -L -I -o /dev/null -w '%{url_effective}')
dmgfile="Slack.dmg"
dir=/tmp/$dmgfile

#download file
echo "Downloading..."
sudo /usr/bin/curl --retry 3 -L "$finalURL" -o $dir

#mount dmg
echo "Mounting dmg..."
/usr/bin/hdiutil attach $dir -nobrowse -quiet

#copy app over
echo "Coping App to Applications folder..."
ditto -rsrc "/Volumes/Slack/Slack.app" "/Applications/Slack.app"

#sleep 3
echo "Sleep 3"
sleep 3

#unmount dmg
echo "Unmounting dmg...."
/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "Slack" | awk '{print $1}') -quiet

#delete temp file
echo "Cleaning up..."
sudo rm -Rf $dir



#open Slack
open /Applications/Slack.app

exit 0
