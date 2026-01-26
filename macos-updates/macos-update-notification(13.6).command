#!/usr/bin/env bash
#
# Script Name: Critical macOS 13.6 Zero‑Day Alert
# Description:
#   - Ensures device is on macOS 13.6 (Ventura).
#   - If already on 13.6, runs Jamf recon and exits.
#   - If not, ensures the 13.6 installer is present and correct.
#   - Uses a counter file to throttle how often the swiftDialog alert appears.
#   - Checks disk space and warns if there is < 40 GB free.
#

set -euo pipefail

#######################################
# Globals
#######################################

readonly TARGET_VERSION="13.6"
readonly VENTURA_INSTALLER="/Applications/Install macOS Ventura.app"
readonly INSTALL_ASSISTANT_URL="https://swcdn.apple.com/content/downloads/28/01/042-55926-A_7GZJNO2M4I/asqcyheggme9rflzb3z3pr6vbp0gxyk2eh/InstallAssistant.pkg"
readonly INSTALL_ASSISTANT_DIR="/usr/local/"
readonly INSTALL_ASSISTANT_PKG="InstallAssistant.pkg"

readonly CHECKIN_COUNT_FILE="/tmp/checkinCounter.txt"

# swiftDialog / UI bits
readonly UPDATED_DIALOG_VERSION="2.3.2"
readonly DIALOG_BIN="/usr/local/bin/dialog"
readonly DIALOG_DOWNLOAD_URL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.3.2/dialog-2.3.2-4726.pkg"
readonly DIALOG_DIR="/usr/local/"
readonly SWIFT_DIALOG_PKG="swiftDialog.pkg"
readonly DIALOG_APP_DIR="/Library/Application Support/Dialog/Dialog.app"

readonly WALLPAPER_DIR="/Library/Application Support/wallpaper/"
readonly WALLPAPER_IMG="desktopwallpaper.jpg"
readonly WALLPAPER_PKG_DIR="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"

readonly DIALOG_ICON_DIR="/Library/Application Support/SideIT/ATTIcon.png"
readonly DIALOG_BACKGROUND="${WALLPAPER_DIR}${WALLPAPER_IMG}"
readonly DIALOG_SLACK_URL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
readonly DIALOG_HD_URL="https://sideinc.freshservice.com/support/catalog/items/131"
readonly DIALOG_TITLE_FONT="name=Arial-MT,colour=#CE87C1,size=30"

disk_space_message=""
dl_ready_message=""

#######################################
# Helpers
#######################################

get_os_version() {
  sw_vers -productVersion
}

get_serial() {
  system_profiler SPHardwareDataType | awk '/Serial/ {print $4}'
}

safe_rm() {
  local path="$1"
  [[ -e "${path}" ]] && sudo rm -rf "${path}"
}

#######################################
# Disk space check
#######################################

check_disk_space() {
  local disk_free raw_int

  disk_free="$(df -kh . | tail -n1 | awk '{print $4}')"  # e.g. "100Gi"
  raw_int="${disk_free//Gi}"
  raw_int="$(echo "${raw_int}" | sed 's/[^0-9]//g')"

  echo "DISK_SIZE_FREE: ${disk_free}"
  echo "DISK_SIZE_FREE_INT: ${raw_int}"

  if [[ -z "${raw_int}" ]]; then
    # If parsing fails, do not block but log it.
    echo "Warning: Unable to parse free disk space from '${disk_free}'."
    disk_space_message=""
    return 0
  fi

  # Require at least 40 GB free
  if (( raw_int <= 40 )); then
    echo "Not enough disk space for update."
    disk_space_message="_**ATTENTION: You only have ${raw_int} GB free disk space and need at least 40 GB to perform this update.**_\n\n_**If you need assistance with clearing up some disk space, please reach out to helpdesk@side.com**_"
  else
    echo "Plenty of free disk space."
    disk_space_message=""
  fi
}

#######################################
# swiftDialog install / update
#######################################

install_swiftdialog() {
  # Ensure wallpaper
  if [[ -f "${WALLPAPER_DIR}${WALLPAPER_IMG}" ]]; then
    echo "Wallpaper found, skipping wallpaper install."
  else
    echo "Wallpaper not found, installing wallpaper package…"
    sudo /usr/sbin/installer -pkg "${WALLPAPER_PKG_DIR}" -target /
  fi

  if [[ -x "${DIALOG_BIN}" ]]; then
    echo "swiftDialog found, checking version…"
    local dialog_version
    dialog_version="$(defaults read "${DIALOG_APP_DIR}/Contents/Info" CFBundleShortVersionString)"
    echo "swiftDialog version: ${dialog_version}"

    if [[ "${dialog_version}" != "${UPDATED_DIALOG_VERSION}" ]]; then
      echo "swiftDialog not up to date, updating…"
      sudo /usr/bin/curl -L "${DIALOG_DOWNLOAD_URL}" -o "${DIALOG_DIR}${SWIFT_DIALOG_PKG}"
      sudo /usr/sbin/installer -pkg "${DIALOG_DIR}${SWIFT_DIALOG_PKG}" -target /
      sleep 5
      safe_rm "${DIALOG_DIR}${SWIFT_DIALOG_PKG}"
    else
      echo "swiftDialog version is correct, skipping update."
    fi
  else
    echo "swiftDialog not found, installing…"
    sudo /usr/bin/curl -L "${DIALOG_DOWNLOAD_URL}" -o "${DIALOG_DIR}${SWIFT_DIALOG_PKG}"
    sudo /usr/sbin/installer -pkg "${DIALOG_DIR}${SWIFT_DIALOG_PKG}" -target /
    sleep 5
    safe_rm "${DIALOG_DIR}${SWIFT_DIALOG_PKG}"
  fi

  echo "Checking disk space and launching alert…"
  check_disk_space
  launch_alert
}

#######################################
# Alert dialog
#######################################

launch_alert() {
  local current_os mac_serial
  current_os="$(get_os_version)"
  mac_serial="$(get_serial)"

  local dTitle dMessage dButton1 dButton2 timer dHelp dInfoBox

  dTitle="Side IT Alert: Critical macOS Update Available – ${TARGET_VERSION}"
  dMessage=$(
    cat <<EOF
You are getting this alert because this device needs to be updated to _**macOS ${TARGET_VERSION}**_.

Due to this being a _**Critical Zero‑Day macOS Update**_, you have until Sunday, September 24th, to get the update complete.

_**These alerts will launch every 30–45 minutes and can only be stopped by updating to macOS ${TARGET_VERSION}.**_

${dl_ready_message}

Please make sure all your important data is in Google Drive before proceeding!!

Contact [helpdesk@side.com](mailto:helpdesk@side.com) or #it-support in Slack with any questions.
Thank you!
– Side IT.

${disk_space_message}
EOF
  )

  dButton1="Update Now"
  dButton2="Later"
  timer=$((60 * 10))  # 10 minutes

  dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."

  dInfoBox=$(
    cat <<EOF
__Current macOS:__ ${current_os}

__Update To:__
${TARGET_VERSION}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${DIALOG_SLACK_URL})

__Support Ticket__
[helpdesk@side.com](${DIALOG_HD_URL})
EOF
  )

  "${DIALOG_BIN}" \
    --title "${dTitle}" \
    --titlefont "${DIALOG_TITLE_FONT}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=16" \
    --icon "${DIALOG_ICON_DIR}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --button2text "${dButton2}" \
    --helpmessage "${dHelp}" \
    --height 50% \
    --width 50% \
    --background "${DIALOG_BACKGROUND}" \
    --infobox "${dInfoBox}" \
    --timer "${timer}"

  local returncode=$?

  case "${returncode}" in
    0)
      echo "User chose: Update Now"
      sudo open "${VENTURA_INSTALLER}"
      ;;
    2)
      echo "User chose: Later"
      ;;
    *)
      echo "Dialog dismissed or error (exit code ${returncode}); no explicit action."
      ;;
  esac
}

#######################################
# Ventura 13.6 installer handling
#######################################

ensure_ventura_installer() {
  local osversion mac_serial installer_version

  osversion="$(get_os_version)"
  mac_serial="$(get_serial)"

  echo "Checking for target macOS ${TARGET_VERSION}…"
  echo "Current version: ${osversion}"

  if [[ "${osversion}" == "${TARGET_VERSION}" ]]; then
    echo "macOS is already on ${TARGET_VERSION}; running recon and exiting."
    sudo /usr/local/bin/jamf recon
    exit 0
  fi

  echo "macOS ${osversion} is not ${TARGET_VERSION}, checking installer…"

  if [[ -d "${VENTURA_INSTALLER}" ]]; then
    echo "Installer found, checking DTPlatformVersion…"
    installer_version="$(defaults read "${VENTURA_INSTALLER}/Contents/Info.plist" DTPlatformVersion)"
    echo "Installer DTPlatformVersion: ${installer_version}"

    if [[ "${installer_version}" != "${TARGET_VERSION}" ]]; then
      echo "Installer not at ${TARGET_VERSION}, removing and redownloading."
      safe_rm "${VENTURA_INSTALLER}"
    else
      echo "Installer is for ${TARGET_VERSION}; skipping download and launching alert."
    fi
  else
    echo "Installer not found; downloading ${TARGET_VERSION} InstallAssistant.pkg…"
    local macOSPKG_PATH
    macOSPKG_PATH="${INSTALL_ASSISTANT_DIR}${INSTALL_ASSISTANT_PKG}"

    /usr/bin/curl -L "${INSTALL_ASSISTANT_URL}" -o "${macOSPKG_PATH}"
    /usr/sbin/installer -pkg "${macOSPKG_PATH}" -target /
    sleep 5
    safe_rm "${macOSPKG_PATH}"
  fi

  echo "Verifying installer after potential download…"
  if [[ -d "${VENTURA_INSTALLER}" ]]; then
    installer_version="$(defaults read "${VENTURA_INSTALLER}/Contents/Info.plist" DTPlatformVersion)"
    echo "Installer DTPlatformVersion after download: ${installer_version}"

    if [[ "${installer_version}" != "${TARGET_VERSION}" ]]; then
      echo "Installer still not correct; proceed with alert but without convenience message."
      dl_ready_message=""
      install_swiftdialog
    else
      echo "Installer for ${TARGET_VERSION} verified; setting convenience message."
      dl_ready_message="For your convenience, you have the \"Install macOS Ventura\" application in the /Applications folder ready to be installed. Just click \"Update Now\" to launch the installer."
      install_swiftdialog
    fi
  else
    echo "Installer not present after download; launching alert without convenience message."
    dl_ready_message=""
    install_swiftdialog
  fi
}

#######################################
# Check‑in throttling
#######################################

check_timers() {
  local count

  if [[ -f "${CHECKIN_COUNT_FILE}" ]]; then
    echo "Check‑in counter file found; reading value…"
    count="$(tail -n 1 "${CHECKIN_COUNT_FILE}" | sed 's/[^0-9]//g')"
    count="${count:-0}"
    echo "Current check‑in count: ${count}"

    if (( count < 2 )); then
      echo "Check‑in count < 2; incrementing and exiting (no alert this time)."
      count=$((count + 1))

      safe_rm "${CHECKIN_COUNT_FILE}"
      echo "${count}" | sudo tee "${CHECKIN_COUNT_FILE}" >/dev/null

      echo "Exiting script without alert."
      exit 0
    else
      echo "Check‑in count == 2; resetting counter and launching alert."
      count=1
      safe_rm "${CHECKIN_COUNT_FILE}"
      echo "${count}" | sudo tee "${CHECKIN_COUNT_FILE}" >/dev/null

      ensure_ventura_installer
    fi
  else
    echo "No check‑in counter file; treating as fresh push and launching alert."
    count=1
    safe_rm "${CHECKIN_COUNT_FILE}"
    echo "${count}" | sudo tee "${CHECKIN_COUNT_FILE}" >/dev/null

    ensure_ventura_installer
  fi
}

#######################################
# Main
#######################################

main() {
  local osversion
  osversion="$(get_os_version)"

  echo "Starting macOS ${TARGET_VERSION} check…"
  echo "Current macOS version: ${osversion}"

  if [[ "${osversion}" == "${TARGET_VERSION}" ]]; then
    echo "macOS is up to date with ${osversion}; running recon and exiting."
    sudo /usr/local/bin/jamf recon
    exit 0
  fi

  echo "macOS ${osversion} is not ${TARGET_VERSION}; applying check‑in throttling."
  check_timers
}

main "$@"



--------OG
#!/bin/bash

checkDiskSpace () {

	DISK_SIZE_FREE=$(df -kh . | tail -n1 | awk '{print $4}')
	DISK_SIZE_FREE_INT="${DISK_SIZE_FREE//Gi}"
	DISK_SIZE_FREE_INT=$(echo "$DISK_SIZE_FREE_INT" | sed 's/[^0-9]//g')

	echo "DISK_SIZE_FREE: "$DISK_SIZE_FREE
	echo "DISK_SIZE_FREE_INT: "$DISK_SIZE_FREE_INT
	


	#if SSD has less than 40GB of free space, do not proceed
	if [[ "$DISK_SIZE_FREE_INT" -le 40 ]]; then
		
		echo "not enough room"
		diskSpace="_**ATTENTION: You only have $DISK_SIZE_FREE_INT GB free disk space and need at least 40 GB to perform this update.**_
		\n_**If you need assistance with clearing up some disk space, please reach out to helpdesk@side.com**_"
	else
		echo "Plenty of space, running installer"
		diskSpace=""
	fi

}

launchAlert () {
    updatedDialogVersion=2.3.2
	dialog_bin="/usr/local/bin/dialog"
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
	
	
	currentOSVersion=$(sw_vers -productVersion)
	macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	
	
dTitle="Side IT Alert: Critical macOS Update Available - 13.6"
dMessage="You are getting this alert because this device needs to be updated to _**macOS 13.6**_ 
\nDue to this being a _**Critical Zero-Day macOS Update**_, you have until Sunday, September 24th, to get the update complete.

_**These alerts will launch every 30-45 minutes and can only be stopped by updating to macOS 13.6**_

$dlReady

Please make sure all your important data is in Google Drive before proceeding!!\n\n
Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT.

$diskSpace"
dButton1="Update Now"
dButton2="Later"
timer=600 #60 seconds * 10 min = 600
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
13.6\n\n
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"


		updateSelect=$(${dialog_bin} \
		    --title "$dTitle" \
			--titlefont "$dialogTitleFont" \
		    --message "$dMessage" \
			--messagefont "name=Arial-MT,size=16" \
		    --icon "$dIconDir" \
			--iconsize 120 \
		    --button1text "$dButton1" \
			--helpmessage "$dHelp" \
			--height 50% \
			--width 50% \
			--background "$dBackDir" \
			--infobox "$dInfoBox" \
	        --timer "$timer" \
	        --button2text "$dButton2" 
	
		)		
	
	
		


		#Button pressed Stuff
		returncode=$?


		case ${returncode} in
		    0)  echo "Pressed Button 1: update"
			sudo open "/Applications/Install macOS Ventura.app"

		
	
		        ;;

		    2)  echo "Pressed Button 2: Postpone"
	
		

		        ;;
		
		    *)  echo "Error: No Button Pressed. Launcing Alert and dismissing. exit code ${returncode}"
		
		
        

		        ;;
		esac
	

}

installSwiftDialog () {
	
    updatedDialogVersion=2.3.2
	dialog_bin="/usr/local/bin/dialog"
	#dialog_download_url="https://github.com/bartreardon/swiftDialog/releases/download/v2.2.1/dialog-2.2.1-4591.pkg"
	dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.3.2/dialog-2.3.2-4726.pkg"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"
    
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
	
	dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
	dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
	dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
	dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
	dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
    
    if [ -f "$wallpaperDir$wallpaperImg" ]; then
    echo "Wallpaper found, skipping install"
    else
    echo "Installing wallpaper"
    sudo /usr/sbin/installer -pkg "$wallpaperPKGDir" -target /
    fi
    

	if [ -f $dialog_bin ]; then
		echo "Dialog app found, checking version"
        dialogVersion=$(defaults read /Library/Application\ Support/Dialog/Dialog.app/Contents/Info CFBundleShortVersionString)
		echo "Dialog Version: "$dialogVersion

		if [ $dialogVersion != $updatedDialogVersion ]; then
			#if not equal, then update
			echo "Dialog not up to date, updating..."
   		    echo "Dialog app not found, downloading and installing dialog"
	  	    ##Download swiftDialog
	  	    sudo /usr/bin/curl -L "$dialog_download_url" -o "$dialogDir$swiftDialogPKG"
	
	    	##Installing Dialog
	       sudo /usr/sbin/installer -pkg "$dialogDir$swiftDialogPKG" -target /
		    sleep 5
	
		    #Cleanup
		    sudo rm -r "$dialogDir$swiftDialogPKG"

        else
	        #if equal, do not update
	        echo "Dialog Version Correct, skipping update"
        fi
        
        
        
	else 
		echo "Dialog app not found, downloading and installing dialog"
	    ##Download swiftDialog
	    sudo /usr/bin/curl -L "$dialog_download_url" -o "$dialogDir$swiftDialogPKG"
	
	    ##Installing Dialog
	    sudo /usr/sbin/installer -pkg "$dialogDir$swiftDialogPKG" -target /
		sleep 5
	
		#Cleanup
		sudo rm -r "$dialogDir$swiftDialogPKG"
	fi
echo "Checking disk space and launching alert..."
checkDiskSpace
launchAlert	

}

checkmacOSVersion () {

macOSVersion=13.6
##Device info
osversion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')


echo "Checking for 13.6"
echo "Version: "$osversion

if [ "$osversion" == "$macOSVersion" ]; then
	echo "macOS is up to date with $osversion, running recon and exiting..."
    sudo jamf recon
	exit 0
else
	echo "macOS $osversion NOT on $macOSVersion, proceeding with installer check."
fi




echo "Checking for 13.6"

if [ -a "/Applications/Install macOS Ventura.app" ]; then
	echo "Installer found, checking version..."
    installer_version=$(defaults read "/Applications/Install macOS Ventura.app/Contents/info.plist" DTPlatformVersion)
	echo "Version found: "$installer_version
	
	if [ "$installer_version" != "13.6" ]; then
		echo "Incorrect version, deleting and downloading 13.6"
		sudo rm -rf "/Applications/Install macOS Ventura.app"
	else
		echo "Correct version, skipping download and launching alert"
	fi
else
	echo "Installer not found, downloading 13.6"
	#macOS InstallAssistant PKG - this will contain and exract Install macOS Ventura.app
	#macOSURL - 13.6 - updated 09.21.2023
	macOSURL='https://swcdn.apple.com/content/downloads/28/01/042-55926-A_7GZJNO2M4I/asqcyheggme9rflzb3z3pr6vbp0gxyk2eh/InstallAssistant.pkg'
	macOSDir="/usr/local/"
	macOSPKG="InstallAssistant.pkg"
	
	#downloading InstallAssistant.pkg for Ventura
	curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
	#install - extract "Install macOS Ventura.app"
	/usr/sbin/installer -pkg "$macOSDir$macOSPKG" -target /
	sleep 5
	#Cleanup - remove InstallAssistant.pkg
	sudo rm -rf "$macOSDir$macOSPKG"
fi

echo "Checking installer after download"
if [ -a "/Applications/Install macOS Ventura.app" ]; then
	echo "Installer found, checking version..."
    installer_version=$(defaults read "/Applications/Install macOS Ventura.app/Contents/info.plist" DTPlatformVersion)
echo "Version pulled: "$installer_version

	if [ "$installer_version" != "13.6" ]; then
	echo "wrong version, running recon and exiting"
	dlReady=" "
	installSwiftDialog
    else
    echo "Installer found with correct version, checking time"
	dlReady="For your convenience, you have the \"Install macOS Ventura\" application in the /Applications folder ready to be installed. Just click \"Update Now\" to launch the installer."
    installSwiftDialog
    fi
else
	echo "Installer failed, setting message and launching alert"
dlReady=" "
installSwiftDialog
fi
}

checkTimers () {
	### Checking for check in file
	checkinCountFile='/tmp/checkinCounter.txt'
	
	  #checkinCountFile='/usr/local/checkinCount.txt'
	  
	  
	  if [ -f "$checkinCountFile" ]; then
		  echo "Checkin file found, extracting data"
		  
		  echo "Pulling checkin count data..."
		  checkinCountPull=$( tail -n 1 $checkinCountFile)
		  echo $checkinCountPull pulled from file
		  
		  
		  if [[ "$checkinCountPull" < 2 ]]; then
			  echo "Checkin less than 2 since alert launch, counting up and exiting..."
			  echo "Adding 1 to checkin count"
			  checkinCountPull=$(echo "$checkinCountPull" | sed 's/[^0-9]//g')
			  echo "checkinCountPull after convert: "$checkinCountPull
			  let checkinCountPull=$checkinCountPull+1
			  echo "Remaining checkins: "$checkinCountPull
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			  echo "Exiting Script..."
			  
		  else
			  echo "Checkin is 2, checking postpone amounts"
			  
			  
			  echo "Resetting checkin..."
			  let checkinCountPull=1
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			   echo "Launching alert..."
			  checkmacOSVersion
			  
		   fi
		   
		   
	   else
		    
		  echo "Fresh push, launching primary alert"
		  let checkinCountPull=1
		  echo "Total Checkins: "$checkinCountPull
	  
		  echo "Removing checkinCountFile"
		  sudo rm -rf $checkinCountFile
	  
		  echo "Creating new checkinCountFile with updated checkin count"
		  echo $checkinCountPull >> $checkinCountFile
		  
		  echo "Launching alert..."
		  checkmacOSVersion
	      fi
	  			

}

##Starting
###CHECK macOS Version
macOSVersion=13.6
##Device info
osversion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')


echo "Checking for 13.6"
echo "Version: "$osversion

if [ "$osversion" == "$macOSVersion" ]; then
	echo "macOS is up to date with $osversion, running recon and exiting..."
    sudo jamf recon
	exit 0
else
	echo "macOS $osversion NOT on $macOSVersion, proceeding with installer check."
	checkTimers
fi
