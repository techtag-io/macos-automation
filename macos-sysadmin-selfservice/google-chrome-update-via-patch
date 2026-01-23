#!/usr/bin/env bash
#
# Script Name: Update Google Chrome (macOS)
# Description:
#   Compares the installed Chrome version to the latest macOS stable build.
#   If outdated, downloads the universal DMG, installs Chrome, runs Jamf recon,
#   and triggers a zero-day alert policy.
#

set -euo pipefail

get_latest_chrome_version() {
  # omahaproxy CSV history; filter for mac,stable and take first version column
  curl -s "https://omahaproxy.appspot.com/history" \
    | awk -F',' '/mac,stable/ { print $3; exit }'
}

get_installed_chrome_version() {
  /usr/libexec/PlistBuddy \
    -c "Print CFBundleShortVersionString" \
    "/Applications/Google Chrome.app/Contents/Info.plist"
}

download_and_install_chrome() {
  local url dmgfile volname logfile

  # Universal DMG works across Intel and Apple Silicon
  url="https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg"
  dmgfile="googlechrome.dmg"
  volname="Google Chrome"
  logfile="/Library/Logs/GoogleChromeInstallScript.log"

  echo "Download URL: ${url}"
  echo "DMG file: ${dmgfile}"
  echo "Volume name: ${volname}"

  {
    echo "--"
    echo "$(date): Downloading latest version."
  } >>"${logfile}"

  echo "Downloading latest Chrome DMG…"
  /usr/bin/curl -s -o "/tmp/${dmgfile}" "${url}"

  echo "$(date): Mounting installer disk image." >>"${logfile}"
  echo "Mounting installer disk image…"
  /usr/bin/hdiutil attach "/tmp/${dmgfile}" -nobrowse -quiet

  echo "$(date): Installing…" >>"${logfile}"
  echo "Installing Chrome to /Applications…"
  ditto -rsrc "/Volumes/${volname}/Google Chrome.app" "/Applications/Google Chrome.app"

  echo "Waiting 10 seconds before unmount…"
  sleep 10

  echo "$(date): Unmounting installer disk image." >>"${logfile}"
  echo "Unmounting installer disk image…"
  /usr/bin/hdiutil detach "$(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}')" -quiet || true

  echo "Waiting 10 seconds before cleanup…"
  sleep 10

  echo "$(date): Deleting disk image." >>"${logfile}"
  echo "Deleting DMG from /tmp…"
  rm -f "/tmp/${dmgfile}"
}

main() {
  local latest_chrome installed_chrome arch

  echo "Determining latest macOS stable Chrome version…"
  latest_chrome="$(get_latest_chrome_version || true)"
  echo "Latest Chrome version (stable, mac): ${latest_chrome}"

  echo "Checking installed Chrome version…"
  if [[ -f "/Applications/Google Chrome.app/Contents/Info.plist" ]]; then
    installed_chrome="$(get_installed_chrome_version)"
  else
    installed_chrome="not-installed"
  fi
  echo "Installed Chrome version: ${installed_chrome}"
  echo

  if [[ "${installed_chrome}" == "${latest_chrome}" ]]; then
    echo "Chrome is up to date. Running Jamf recon, then exiting."
    sudo /usr/local/bin/jamf recon
    exit 0
  fi

  echo "Chrome is not up to date; updating…"

  arch="$(uname -m)"
  if [[ "${arch}" == "arm64" ]]; then
    echo "Hardware: Apple Silicon (arm64)"
  else
    echo "Hardware: Intel (${arch})"
  fi
  echo "Using universal Chrome DMG for install."

  download_and_install_chrome

  echo "Running Jamf recon after Chrome update…"
  sudo /usr/local/bin/jamf recon

  echo
  echo "Verifying installed Chrome version after update…"
  installed_chrome="$(get_installed_chrome_version)"
  echo "Installed Chrome version: ${installed_chrome}"

  echo "Triggering Jamf zero-day alert policy (if configured)…"
  sudo /usr/local/bin/jamf policy -event chromeUpdateAlertZeroDay

  echo "Done."
}

main "$@"



--------OG
#!/bin/bash

#Latest Chrome Version
latestChromeV=$(curl -s "https://omahaproxy.appspot.com/history" | awk -F',' '/mac,stable/{print $3; exit}')
echo "Latest Chrome Version: "$latestChromeV

#check Current Installed Chrome Version
installedChromeV=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" /Applications/Google\ Chrome.app/Contents/Info.plist)
echo "Installed Chrome Version: "$installedChromeV
echo ""
echo ""

if [ "$installedChromeV" = "$latestChromeV" ]; then
	echo "Chrome up to date! Running Recon then exiting..."
    #update Jamf first
	sudo jamf recon
    exit 0
else
	echo "Not up to date, updating..."
fi

#identify M1 vs Intel to target URL
if [[ `uname -m` == 'arm64' ]]; then
  echo "Sicilone: M1"
  siliconType="M1"
  url='https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg '
else
echo "Silicone: Intel"
siliconType="intel"
#url="https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg" 
#same URL as M1
echo "replaced URL"
url='https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg '
fi

dmgfile="googlechrome.dmg"
volname="Google Chrome"
logfile="/Library/Logs/GoogleChromeInstallScript.log"

echo "DMG: "$dmgfile
echo "VolName: "$volname



/bin/echo "--" >> ${logfile}
/bin/echo "`date`: Downloading latest version." >> ${logfile}
echo "Downloading latest version."


/usr/bin/curl -s -o /tmp/${dmgfile} ${url}
/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
echo "Mounting installer disk image."


/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
/bin/echo "`date`: Installing..." >> ${logfile}
echo "Installing..."


ditto -rsrc "/Volumes/${volname}/Google Chrome.app" "/Applications/Google Chrome.app"
/bin/sleep 10
/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
echo "Unmounting installer disk image."

/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
/bin/sleep 10
/bin/echo "`date`: Deleting disk image." >> ${logfile}
echo "Deleting disk image."


/bin/rm /tmp/"${dmgfile}"

#run recon to update jamf
echo "running recon"
sudo jamf recon

echo ""
echo ""
installedChromeV=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" /Applications/Google\ Chrome.app/Contents/Info.plist)
echo "Installed Chrome Version: "$installedChromeV

#trigger zero day alert - if this policy is off, the alert will NOT trigger
sudo jamf policy -event chromeUpdateAlertZeroDay
