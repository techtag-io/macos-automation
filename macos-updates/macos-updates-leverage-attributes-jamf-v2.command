#!/usr/bin/env bash
#
# Script Name: Guided macOS Upgrade with swiftDialog
# Description:
#   - Prompts user to download a specific macOS installer (InstallAssistant.pkg)
#   - Shows a progress-style dialog while downloading and expanding the app
#   - If the installer already exists, prompts directly to install
#   - Handles Apple Silicon vs Intel, with password verification for startosinstall
#   - Uses swiftDialog for all user-facing alerts and blocking UI
#

set -euo pipefail

#######################################
# Parameters and globals
#######################################

# Jamf parameters
macOSVersion="${4:-13.4.1}"        # e.g. 13.4.1
dlmacOSName="${5:-Ventura}"        # e.g. Ventura

# Device info
currentOSVersion="$(sw_vers -productVersion)"
macSerial="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"

# macOS InstallAssistant (downloads Install macOS ${dlmacOSName}.app)
macOSURL='https://swcdn.apple.com/content/downloads/63/49/032-84910-A_3SSTBN1HDA/h89vitwfbzt54jcbwpfwkmrn12smedicny/InstallAssistant.pkg'
macOSDir="/usr/local/"
macOSPKG="InstallAssistant.pkg"

# swiftDialog / branding
dialog_bin="/usr/local/bin/dialog"
dialog_download_url="https://github.com/bartreardon/swiftDialog/releases/download/v2.2.1/dialog-2.2.1-4591.pkg"
dialogDir="/usr/local/"
swiftDialogPKG="swiftDialog.pkg"
dialogAppDir="/Library/Application Support/Dialog/Dialog.app"

dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"

wallpaperDir="/Library/Application Support/wallpaper/"
wallpaperImg="desktopwallpaper.jpg"
wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"

# ephemeral state
userApprovedConfirmDir="/tmp/macOS_update_pass.txt"
currentUser=""
postPoneWindowSelected=""
userPass=""

#######################################
# Helpers
#######################################

safe_rm() {
  local path="$1"
  [[ -e "${path}" ]] && sudo rm -rf "${path}"
}

get_logged_in_user() {
  currentUser="$(scutil <<< 'show State:/Users/ConsoleUser' | awk '/Name :/ { print $3 }')"
  echo "Logged in user: ${currentUser}"
}

#######################################
# swiftDialog installation
#######################################

installSwiftDialog() {
  # Wallpaper
  if [[ -f "${wallpaperDir}${wallpaperImg}" ]]; then
    echo "Wallpaper found; skipping wallpaper install."
  else
    echo "Installing wallpaper package…"
    sudo /usr/sbin/installer -pkg "${wallpaperPKGDir}" -target /
  fi

  # swiftDialog
  if [[ -x "${dialog_bin}" ]]; then
    echo "swiftDialog found; skipping installation."
  else
    echo "swiftDialog not found; downloading and installing…"
    sudo /usr/bin/curl -L "${dialog_download_url}" -o "${dialogDir}${swiftDialogPKG}"
    sudo /usr/sbin/installer -pkg "${dialogDir}${swiftDialogPKG}" -target /
    sleep 5
    safe_rm "${dialogDir}${swiftDialogPKG}"
  fi
}

#######################################
# Blocking install alert (during startosinstall)
#######################################

installAlert() {
  local dTitle dMessage dIconDir web timer caffeineTimer dInfoBox

  dTitle="Installing macOS ${macOSVersion}… Please wait"
  dMessage=$(
    cat <<EOF
macOS ${macOSVersion} is being installed.

This process could take up to 45 minutes. Once done, the device will restart on its own
at which point the update will be complete.

PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWER SOURCE SO IT IS NOT INTERRUPTED!

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you!
Side IT Helpdesk
EOF
  )
  dIconDir="${dialogIconDir}"
  web="https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif"
  timer=$((60 * 45))          # 2700
  caffeineTimer=$((60 * 60))  # 3600

  dInfoBox=$(
    cat <<EOF
__macOS Version__
${currentOSVersion}

__Device Serial__
${macSerial}

__Slack__
[#it-support](${dialogSlackURL})

__Email__
[helpdesk@side.com](${dialogHDURL})
EOF
  )

  caffeinate -i -s -d -t "${caffeineTimer}" &

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=30" \
    --icon "${dIconDir}" \
    --iconsize 250 \
    --webcontent "${web}" \
    --blurscreen \
    --infobox "${dInfoBox}" \
    --background "${dialogBackGroundDir}" \
    --timer "${timer}"
}

#######################################
# Apple Silicon install (password‑gated)
#######################################

appleSiliconInstall() {
  echo "Apple Silicon flow."
  get_logged_in_user

  local passCheck="FAILED"

  while [[ "${passCheck}" != "PASSED" ]]; do
    local dTitle userPasswordNeeded dMessage dButton1 dHelp dInfoBox dialog_output resultCode

    if [[ "${passCheck}" != "FAILED" ]]; then
      dTitle="The update will happen after ${postPoneWindowSelected}"
      userPasswordNeeded="Apple requires the user to authenticate with the computer password to update macOS.
Please confirm your computer password to confirm the update schedule."
    else
      dTitle="INCORRECT PASSWORD! TRY AGAIN…"
      userPasswordNeeded="Apple requires the user to authenticate with the computer password to update macOS.
Please confirm your computer password to confirm the update schedule.

_***INCORRECT PASSWORD, TRY AGAIN…***_"
      dialogTitleFont="name=Arial-MT,colour=#FF0000,size=30"
    fi

    dMessage=$(
      cat <<EOF
Your macOS update to macOS ${macOSVersion} is set to take place after ${postPoneWindowSelected}.
You are still able to install the update yourself before ${postPoneWindowSelected} by going to /Applications and running
"Install macOS ${dlmacOSName}".

PLEASE NOTE THAT FOR THE UPDATE TO BE SUCCESSFUL, YOU NEED TO KEEP THE DEVICE:
1. TURNED ON
2. CONNECTED TO A POWER SOURCE
3. CONNECTED TO THE INTERNET

IF ANY OF THE ABOVE ARE MISSING, THE UPDATE WILL BEGIN THE NEXT TIME
THE DEVICE IS ONLINE, WHICH MAY CAUSE DISRUPTION.

${userPasswordNeeded}

Contact helpdesk@side.com or #it-support in Slack with any questions.
EOF
    )
    dButton1="I Understand"
    dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
    dInfoBox=$(
      cat <<EOF
__Current macOS__
${currentOSVersion}

__Update To__
${macOSVersion}

__Device Serial__
${macSerial}

__Slack__
[#it-support](${dialogSlackURL})

__Support Ticket__
[helpdesk@side.com](${dialogHDURL})
EOF
    )

    dialog_output="$(
      "${dialog_bin}" \
        --title "${dTitle}" \
        --titlefont "${dialogTitleFont}" \
        --message "${dMessage}" \
        --messagefont "name=Arial-MT,size=30" \
        --icon "${dialogIconDir}" \
        --iconsize 120 \
        --button1text "${dButton1}" \
        --helpmessage "${dHelp}" \
        --helptitle "TITLE" \
        --textfield "Password",required,secure \
        --big \
        --infobox "${dInfoBox}" \
        --background "${dialogBackGroundDir}"
    )"

    echo "Confirm output: ${dialog_output}"

    userPass="${dialog_output#Password : }"

    # Validate password
    if dscl . authonly "${currentUser}" "${userPass}" &>/dev/null; then
      echo "Password Check: PASSED"
      passCheck="PASSED"
      printf '%s\n' "${userPass}" >"${userApprovedConfirmDir}"
    else
      echo "Password Check: FAILED"
      passCheck="FAILED"
    fi
  done

  echo "Starting startosinstall for Apple Silicon…"
  printf '%s\n' "${userPass}" | \
    "/Applications/Install macOS ${dlmacOSName}.app/Contents/Resources/startosinstall" \
      --agreetolicense \
      --nointeraction \
      --user "${currentUser}" \
      --stdinpass &

  installAlert
  killall Dialog 2>/dev/null || true
}

#######################################
# Intel install
#######################################

intelInstall() {
  echo "Intel flow."
  get_logged_in_user

  printf '%s\n' "${userPass:-}" | \
    "/Applications/Install macOS ${dlmacOSName}.app/Contents/Resources/startosinstall" \
      --agreetolicense \
      --nointeraction \
      --user "${currentUser}" \
      --stdinpass &

  installAlert
  killall Dialog 2>/dev/null || true
}

#######################################
# Silicon type check and routing
#######################################

siliconCheck() {
  if [[ "$(uname -m)" == "arm64" ]]; then
    echo "Silicon type: Apple Silicon (M1/M2)."
    appleSiliconInstall
  else
    echo "Silicon type: Intel."
    intelInstall
  fi
}

#######################################
# Ask to install (installer already present)
#######################################

askToInstall() {
  local dTitle dMessage dButton1 dButton2 dHelp dInfoBox dialog_output returncode

  dTitle="Side IT Alert: macOS Install"
  dMessage=$(
    cat <<EOF
macOS ${macOSVersion} has successfully downloaded and is ready to be installed.

PLEASE NOTE – Clicking "Install" will automatically block your screen and start the install.
YOU CANNOT USE YOUR COMPUTER DURING THIS TIME!

If you would rather install it later, simply click "Exit".

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you!
– Side IT.
EOF
  )
  dButton1="Install"
  dButton2="Exit"
  dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
  dInfoBox=$(
    cat <<EOF
__Current macOS__
${currentOSVersion}

__Update To__
${macOSVersion}

__Serial__
${macSerial}

__Slack__
[#it-support](${dialogSlackURL})

__Support Ticket__
[helpdesk@side.com](${dialogHDURL})
EOF
  )

  dialog_output="$(
    "${dialog_bin}" \
      --title "${dTitle}" \
      --titlefont "${dialogTitleFont}" \
      --message "${dMessage}" \
      --messagefont "name=Arial-MT,size=30" \
      --icon "${dialogIconDir}" \
      --iconsize 120 \
      --button1text "${dButton1}" \
      --button2text "${dButton2}" \
      --helpmessage "${dHelp}" \
      --helptitle "TITLE" \
      --big \
      --background "${dialogBackGroundDir}" \
      --infobox "${dInfoBox}" \
      --moveable
  )"

  returncode=$?

  case "${returncode}" in
    0)
      echo "User chose Install; running silicon check."
      siliconCheck
      exit 0
      ;;
    2)
      echo "User chose Exit; nothing to do."
      exit 0
      ;;
    *)
      echo "askToInstall dialog exit code ${returncode}; exiting."
      exit 0
      ;;
  esac
}

#######################################
# Download macOS and then prompt to install
#######################################

downloadmacOS() {
  echo "Downloading InstallAssistant for macOS ${macOSVersion}…"
  /usr/bin/curl -L "${macOSURL}" -o "${macOSDir}${macOSPKG}"

  echo "Expanding InstallAssistant.pkg to install app…"
  /usr/sbin/installer -pkg "${macOSDir}${macOSPKG}" -target /
  sleep 5

  safe_rm "${macOSDir}${macOSPKG}"
  killall Dialog 2>/dev/null || true
  sleep 2

  echo "Verifying macOS installer app…"
  if [[ -d "/Applications/Install macOS ${dlmacOSName}.app" ]]; then
    echo "Installer app found; prompting to install."
    askToInstall
  else
    echo "Installer app not found after download; exiting."
    # Optionally: sudo jamf recon -room "macOS Update Fail"
    exit 1
  fi
}

downloadmacOSAlert() {
  local dTitle dMessage dIconDir web timer caffeineTimer dHelp dInfoBox

  dTitle="Side IT Alert: Downloading macOS"
  dMessage=$(
    cat <<EOF
macOS ${macOSVersion} download has begun.

This will take some time. You are free to continue working during this process.

__DO NOT CLOSE THE SELF SERVICE APP OR IT COULD DISRUPT THE DOWNLOAD.__

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you!
– Side IT.
EOF
  )
  dIconDir="${dialogIconDir}"
  web="https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif"
  timer=$((60 * 45))
  caffeineTimer=$((60 * 60))
  dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
  dInfoBox=$(
    cat <<EOF
__Current macOS__
${currentOSVersion}

__Update To__
${macOSVersion}

__Serial__
${macSerial}

__Slack__
[#it-support](${dialogSlackURL})

__Support Ticket__
[helpdesk@side.com](${dialogHDURL})
EOF
  )

  caffeinate -i -s -d -t "${caffeineTimer}" &

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=30" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --helpmessage "${dHelp}" \
    --helptitle "TITLE" \
    --big \
    --background "${dialogBackGroundDir}" \
    --infobox "${dInfoBox}" \
    --webcontent "${web}" \
    --timer "${timer}" \
    --moveable
}

#######################################
# Initial user prompt to download
#######################################

prompt_download() {
  local dTitle dMessage dButton1 dButton2 dHelp dInfoBox returncode

  dTitle="Side IT Alert: macOS Update"
  dMessage=$(
    cat <<EOF
This policy is for updating macOS to the latest version – macOS ${macOSVersion}.

The download will NOT automatically install; you must manually trigger the installation.
The download can take up to 30 minutes to complete depending on your internet bandwidth.

Click "Download" to start the process.
Click "Dismiss" if you prefer to perform this at a later time.

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you!
– Side IT.
EOF
  )
  dButton1="Download"
  dButton2="Dismiss"
  dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
  dInfoBox=$(
    cat <<EOF
__Current macOS__
${currentOSVersion}

__Update To__
${macOSVersion}

__Serial__
${macSerial}

__Slack__
[#it-support](${dialogSlackURL})

__Support Ticket__
[helpdesk@side.com](${dialogHDURL})
EOF
  )

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=30" \
    --icon "${dialogIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --button2text "${dButton2}" \
    --helpmessage "${dHelp}" \
    --helptitle "TITLE" \
    --big \
    --background "${dialogBackGroundDir}" \
    --infobox "${dInfoBox}" \
    --moveable

  returncode=$?

  case "${returncode}" in
    0)
      echo "User chose Download; starting download + download alert."
      downloadmacOS & downloadmacOSAlert
      exit 0
      ;;
    2)
      echo "User chose Dismiss; exiting."
      exit 0
      ;;
    *)
      echo "Download prompt exit code ${returncode}; exiting."
      exit 0
      ;;
  esac
}

#######################################
# Main
#######################################

main() {
  installSwiftDialog

  echo "Verifying if macOS installer is already present…"
  if [[ -d "/Applications/Install macOS ${dlmacOSName}.app" ]]; then
    echo "Installer app found; prompting to install."
    askToInstall
  else
    echo "Installer app not found; prompting user to download."
    prompt_download
  fi
}

main "$@"
