#!/usr/bin/env bash
#
# Script Name: New Device Setup
# Version: 1.0
# Author: Travis Green
# Date: 2025-04
#
# Description:
#   Automates new macOS device setup:
#     - Installs core applications
#     - Applies system configuration via Jamf
#     - Optionally downloads and installs a macOS upgrade
#
# Requirements:
#   - Jamf Pro and related custom triggers
#   - swiftDialog installed or installable
#   - macOS installer URL segments passed in or using defaults
#   - Tools: curl, pmset, dscl, scutil, sw_vers, hdiutil, installer
#
# Notes:
#   - Prompts for AC power before proceeding.
#   - Validates the user’s password before running startosinstall.
#   - Uses swiftDialog JSON list view as a live progress board.

set -euo pipefail

#######################################
# Globals and configuration
#######################################

# Block until Self Service process starts (Jamf workflow bootstrap)
setup_process=""
while [[ -z "${setup_process}" ]]; do
  echo "Waiting for Self Service..."
  setup_process="$(/usr/bin/pgrep 'Self Service' || true)"
  sleep 3
done

# Prevent sleep during setup
caffeinate -dims &
caffeinate_pid=$!

# Parameterised values (Jamf or manual invocation)
readonly macos_version="${4:-15.4.1}"
readonly macos_name="${5:-Sequoia}"
readonly macos_dl_version="${6:-43/58/082-16524-A_VHRNGIT194/ksdv19dcxx90ja7nronzpb4kr4val0imsz}"
readonly updated_dialog_version="${7:-2.5.5}"
readonly dialog_ver_dl="${8:-v2.5.5/dialog-2.5.5-4802.pkg}"

readonly dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/${dialog_ver_dl}"

echo "Setup parameters:"
echo "  macOS target version: ${macos_version}"
echo "  macOS name:           ${macos_name}"
echo "  macOS download path:  ${macos_dl_version}"
echo "  Dialog version:       ${updated_dialog_version}"
echo "  Dialog download URL:  ${dialog_download_url}"
echo

# Dialog paths and branding
readonly dialog_bin="/usr/local/bin/dialog"
readonly dialog_background="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
readonly dialog_icon="/Library/Application Support/SideIT/ATTIcon.png"
readonly report_file="/tmp/report.txt"

rm -f "${report_file}"

readonly dialog_dir="/usr/local/"
readonly swift_dialog_pkg="swiftDialog.pkg"
readonly dialog_slack_url="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
readonly dialog_hd_url="https://sideinc.freshservice.com/support/catalog/items/131"
readonly dialog_title_font="name=Arial-MT,colour=#FFC0CB,size=30"

# User and device info
echo "Getting logged-in user…"
current_user="$(scutil <<< 'show State:/Users/ConsoleUser' | awk '/Name :/ { print $3 }')"
current_uid="$(id -u "${current_user}")"
echo "Logged-in user: \"${current_user}\""

current_os_version="$(sw_vers -productVersion)"
mac_serial="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"

first_name=""
user_pass=""

#######################################
# Helper: pull first name
#######################################

firstname_pull() {
  local realname

  current_user="$(scutil <<< 'show State:/Users/ConsoleUser' | awk '/Name :/ { print $3 }')"
  realname="$(dscl . -read "/Users/${current_user}" RealName 2>/dev/null | tail -n +2 || true)"

  if [[ -z "${realname}" || "${realname}" == *"System Administrator"* ]]; then
    first_name=""
  else
    first_name="$(awk '{print $1}' <<< "${realname}")"
  fi

  first_name="${first_name}, "
}

firstname_pull

#######################################
# swiftDialog install / update
#######################################

install_swiftdialog() {
  sleep 5

  if [[ -x "${dialog_bin}" ]]; then
    echo "swiftDialog found, checking version…"
    local dialog_version
    dialog_version="$(defaults read '/Library/Application Support/Dialog/Dialog.app/Contents/Info' CFBundleShortVersionString)"
    echo "swiftDialog version: ${dialog_version}"

    if [[ "${dialog_version}" != "${updated_dialog_version}" ]]; then
      echo "swiftDialog not up to date, updating…"
      sudo /usr/bin/curl -L "${dialog_download_url}" -o "${dialog_dir}${swift_dialog_pkg}"
      sudo /usr/sbin/installer -pkg "${dialog_dir}${swift_dialog_pkg}" -target /
      sleep 5
      sudo rm -f "${dialog_dir}${swift_dialog_pkg}"
    else
      echo "swiftDialog version is current, skipping update."
    fi
  else
    echo "swiftDialog not found, installing…"
    sudo /usr/bin/curl -L "${dialog_download_url}" -o "${dialog_dir}${swift_dialog_pkg}"
    sudo /usr/sbin/installer -pkg "${dialog_dir}${swift_dialog_pkg}" -target /
    sleep 5
    sudo rm -f "${dialog_dir}${swift_dialog_pkg}"
  fi
}

#######################################
# Power checks
#######################################

power_check_dialog() {
  local title message timer web infobox

  title="Please Connect To A Power Source"
  message=$(
    cat <<EOF
Side's new device setup is about to start.
This includes installing several applications and a full macOS update if necessary.

**Please connect the computer to a power source to ensure the device does not shut off.**

Contact [helpdesk@side.com](mailto:helpdesk@side.com) or #it-support in Slack with any questions.
Thank you!
Side IT Helpdesk
EOF
  )
  timer=120
  web="https://i.pinimg.com/originals/59/df/95/59df95ecfb490ed3bab39a283ae7d8fa.gif"
  infobox=$(
    cat <<EOF
__macOS Version__
${current_os_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Email__
[helpdesk@side.com](${dialog_hd_url})
EOF
  )

  "${dialog_bin}" \
    --title "${title}" \
    --titlefont "${dialog_title_font}" \
    --message "${message}" \
    --messagefont "name=Arial-MT,size=20,colour=#000000" \
    --icon "${dialog_icon}" \
    --iconsize 250 \
    --infobox "${infobox}" \
    --webcontent "${web}" \
    --background "${dialog_background}" \
    --timer "${timer}" \
    --blurscreen
}

is_it_plugged_in() {
  check_power_source() {
    pmset -g batt | grep -q "AC Power"
  }

  launch_power_dialog() {
    until check_power_source; do
      if pgrep -x "Dialog" >/dev/null; then
        echo "Power dialog already running."
      else
        echo "Launching power dialog."
        power_check_dialog &
      fi

      echo "Waiting for AC power…"
      sleep 1
    done

    killall Dialog 2>/dev/null || true
  }

  if check_power_source; then
    echo "The laptop is running on AC power."
  else
    echo "The laptop is running on battery power."
    power_check_dialog &
    launch_power_dialog
  fi
}

#######################################
# Password prompt and validation
#######################################

check_password() {
  local pass_check="FAILED"
  local pass_title="Attention: Computer Password Required"
  local wrong_pass_message=""

  until [[ "${pass_check}" == "PASSED" ]]; do
    local title message button help infobox output result_code

    title="${pass_title}"
    message=$(
      cat <<EOF
In order to ensure that your MacBook is up to date and ready to go, the Side Device Setup Process will automatically download and install the latest version of macOS (currently ${current_os_version}).

As part of macOS security, this upgrade requires your computer password.

**${wrong_pass_message}**

In the field below, please type in the password you created a few minutes ago when you created your new account and click the **Start** button to begin the setup process.

Contact [helpdesk@side.com](mailto:helpdesk@side.com) or #it-support in Slack with any questions.
EOF
    )
    button="Start"
    help="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
    infobox=$(
      cat <<EOF
__Current macOS:__ ${current_os_version}

__Update To:__
${macos_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Support Ticket__
[helpdesk@side.com](${dialog_hd_url})
EOF
    )

    output="$(
      "${dialog_bin}" \
        --title "${title}" \
        --titlefont "${dialog_title_font}" \
        --message "${message}" \
        --messagefont "name=Arial-MT,size=20,colour=#000000" \
        --icon "${dialog_icon}" \
        --iconsize 120 \
        --button1text "${button}" \
        --helpmessage "${help}" \
        --helptitle "TITLE" \
        --textfield "Password",required,secure \
        --big \
        --infobox "${infobox}" \
        --background "${dialog_background}" \
        --blurscreen
    )"

    # Extract password from dialog output
    user_pass="${output#Password: }"

    if dscl . authonly "${current_user}" "${user_pass}" &>/dev/null; then
      echo "Password check: PASSED"
      pass_check="PASSED"
      pass_title="Computer Password Needed"
    else
      echo "Password check: FAILED"
      pass_check="FAILED"
      wrong_pass_message="You have typed an incorrect password. Try again!"
      pass_title="Incorrect password… try again!"
    fi
  done
}

#######################################
# SwiftDialog JSON progress board
#######################################

launch_progress_dialog() {
  firstname_pull

  local json_file="/Library/Application Support/SideIT/diagnostic_test.json"

  cat <<EOF >"${json_file}"
{
  "title": "Side Inc New Device Setup",
  "message": "${first_name}Your computer is being set up. Hang tight! Feel free to refill your coffee.\nNote: if there is a macOS update, it could take up to 45 minutes more depending on your internet speed.",
  "listitem": [
    { "title": "Gathering some things", "icon": "/Library/Application Support/SideIT/ATTIcon.png", "status": "pending", "statustext": "Pending" },
    { "title": "Google Chrome", "icon": "https://upload.wikimedia.org/wikipedia/commons/8/87/Google_Chrome_icon_%282011%29.png", "status": "pending", "statustext": "Pending" },
    { "title": "Google Drive", "icon": "https://icons.iconarchive.com/icons/marcus-roberto/google-play/512/Google-Drive-icon.png", "status": "pending", "statustext": "Pending" },
    { "title": "Slack", "icon": "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Slack_icon_2019.svg/2048px-Slack_icon_2019.svg.png", "status": "pending", "statustext": "Pending" },
    { "title": "Zoom", "icon": "https://cdn.prod.website-files.com/5ee732bebd9839b494ff27cd/5eefe1691c86f247d55e8a8b_Zoom-App-Icon-2.webp", "status": "pending", "statustext": "Pending" },
    { "title": "Side IT Apps", "icon": "/Library/Application Support/SideIT/finishing.png", "status": "pending", "statustext": "Pending" },
    { "title": "Okta Verify Desktop", "icon": "https://plugins.miniorange.com/wp-content/uploads/2022/06/drupal-okta-verify.png", "status": "pending", "statustext": "Pending" },
    { "title": "System Settings", "icon": "/Library/Application Support/SideIT/macosupdates.png", "status": "pending", "statustext": "Pending" },
    { "title": "Checking Apps", "icon": "/System/Applications/App Store.app/Contents/Resources/AppIcon.icns", "status": "pending", "statustext": "Pending" },
    { "title": "macOS Updates", "icon": "https://sm.pcmag.com/pcmag_uk/review/a/apple-maco/apple-macos-sequoia_h3sb.png", "status": "pending", "statustext": "Pending" }
  ]
}
EOF

  local infobox
  infobox=$(
    cat <<EOF
__Current macOS:__ ${current_os_version}

__Update To:__
${macos_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Support Ticket__
[helpdesk@side.com](${dialog_hd_url})
EOF
  )

  "${dialog_bin}" \
    --jsonfile "${json_file}" \
    --infobox "${infobox}" \
    --big \
    --ontop \
    --progress \
    --icon "${dialog_icon}" \
    --background "${dialog_background}" \
    --blurscreen \
    --messagefont "name=Arial-MT,size=20,colour=#000000" \
    --titlefont "${dialog_title_font}" \
    --button1text " " \
    --button1disabled &
  dialog_pid=$!

  trap 'rm -f "${json_file}"; kill "${dialog_pid}" 2>/dev/null || true' EXIT
}

update_list_item() {
  local index="$1"
  local status="$2"
  local status_text="$3"

  # Placeholder for advanced listitem updates via swiftDialog run command / JSON delta.
  # For now, log the intended update.
  echo "listitem: index=${index}, status=${status}, statustext=${status_text}" >>/var/tmp/dialog.log
}

#######################################
# Installations / tasks
#######################################

initialize() {
  update_list_item 0 "wait" "Warming up…"
  echo "Initialization step."
  sleep 3
  update_list_item 0 "success" "Done"
}

google_chrome() {
  update_list_item 1 "wait" "Downloading Chrome"

  local url dmgfile volname logfile
  url="https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg"
  dmgfile="googlechrome.dmg"
  volname="Google Chrome"
  logfile="/Library/Logs/GoogleChromeInstallScript.log"

  {
    echo "--"
    echo "$(date): Downloading latest version."
  } >>"${logfile}"

  /usr/bin/curl -s -o "/tmp/${dmgfile}" "${url}"
  echo "$(date): Mounting installer disk image." >>"${logfile}"
  /usr/bin/hdiutil attach "/tmp/${dmgfile}" -nobrowse -quiet

  sleep 2
  update_list_item 1 "wait" "Installing Chrome"
  echo "$(date): Installing…" >>"${logfile}"

  ditto -rsrc "/Volumes/${volname}/Google Chrome.app" "/Applications/Google Chrome.app"
  sleep 10

  echo "$(date): Unmounting installer disk image." >>"${logfile}"
  /usr/bin/hdiutil detach "$(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}')" -quiet
  sleep 10

  echo "$(date): Deleting disk image." >>"${logfile}"
  rm -f "/tmp/${dmgfile}"

  sleep 2
  update_list_item 1 "success" "Done"
}

google_drive() {
  update_list_item 2 "wait" "Downloading Drive"

  local url dmg pkg dirdmg dirpkg
  url="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
  dmg="GoogleDrive.dmg"
  pkg="GoogleDrive.pkg"
  dirdmg="/tmp/${dmg}"
  dirpkg="/tmp/${pkg}"

  /usr/bin/curl -L -o "${dirdmg}" "${url}"
  sleep 20

  /usr/bin/hdiutil attach "${dirdmg}" -nobrowse -quiet
  ditto -rsrc "/Volumes/Install Google Drive/GoogleDrive.pkg" "${dirpkg}"
  sleep 10

  update_list_item 2 "wait" "Installing Drive"
  sudo /usr/sbin/installer -pkg "${dirpkg}" -target / -verbose

  /usr/bin/hdiutil detach "$(/bin/df | /usr/bin/grep 'Install Google Drive' | awk '{print $1}')" -quiet
  sleep 3

  rm -f "${dirdmg}" "${dirpkg}"

  sleep 2
  update_list_item 2 "success" "Done"
}

slack_install() {
  update_list_item 3 "wait" "Downloading Slack"

  local final_url dmgfile dir
  final_url="$(curl -s -L -I -o /dev/null -w '%{url_effective}' "https://slack.com/ssb/download-osx")"
  dmgfile="Slack.dmg"
  dir="/tmp/${dmgfile}"

  sudo /usr/bin/curl --retry 3 -L "${final_url}" -o "${dir}"

  sleep 3
  update_list_item 3 "wait" "Installing Slack"

  /usr/bin/hdiutil attach "${dir}" -nobrowse -quiet
  ditto -rsrc "/Volumes/Slack/Slack.app" "/Applications/Slack.app"
  sleep 5

  /usr/bin/hdiutil detach "$(/bin/df | /usr/bin/grep 'Slack' | awk '{print $1}')" -quiet
  sudo rm -f "${dir}"

  update_list_item 3 "success" "Done"
}

zoom_install() {
  update_list_item 4 "wait" "Downloading Zoom"

  local url pkgfile dir
  url="https://zoom.us/client/latest/ZoomInstallerIT.pkg"
  pkgfile="Zoom.pkg"
  dir="/tmp/${pkgfile}"

  /usr/bin/curl -L -o "${dir}" "${url}"
  sleep 5

  update_list_item 4 "wait" "Installing Zoom"
  sudo /usr/sbin/installer -pkg "${dir}" -target / -verbose
  sleep 5

  sudo rm -f "${dir}"

  update_list_item 4 "wait" "Configuring Zoom"

  cat >/Library/Preferences/us.zoom.config.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>nogoogle</key>
  <true/>
  <key>nofacebook</key>
  <true/>
  <key>zDisableVideo</key>
  <true/>
  <key>zAutoJoinVoip</key>
  <true/>
  <key>zAutoSSOLogin</key>
  <true/>
  <key>zSSOHost</key>
  <string>sideinc.zoom.us</string>
  <key>EnableShareVideo</key>
  <false/>
  <key>zRemoteControlAllApp</key>
  <true/>
  <key>zAutoFullScreenWhenViewShare</key>
  <false/>
  <key>zAutoFitWhenViewShare</key>
  <true/>
  <key>zAutoUpdate</key>
  <true/>
  <key>EnableSilentAutoUpdate</key>
  <true/>
</dict>
</plist>
EOF

  update_list_item 4 "success" "Done"
}

side_intranet_install() {
  update_list_item 5 "wait" "Installing Side IT Apps"

  sudo jamf policy -event inSiderIntranet
  sudo jamf policy -event side_it_handshake
  sleep 3

  update_list_item 5 "success" "Done"
}

okta_verify_install() {
  update_list_item 6 "wait" "Installing Okta Verify"

  sudo jamf policy -event okta_verify
  sleep 3

  update_list_item 6 "success" "Done"
}

system_settings_apply() {
  update_list_item 7 "wait" "Setting Dock"
  sudo jamf policy -event modifyDock
  sleep 3

  update_list_item 7 "wait" "Setting device name"
  sudo jamf policy -event mbpname
  sleep 3

  update_list_item 7 "wait" "Assigning device"
  sudo jamf policy -event uploadUser
  sleep 3

  update_list_item 7 "wait" "Enabling disk encryption"
  sudo jamf policy -event fvenable
  sleep 3

  update_list_item 7 "success" "Done"
}

check_apps() {
  update_list_item 8 "wait" "Checking apps are installed"
  sleep 2

  local missing_apps=""
  local app_dir="/Applications/"
  local app_names=(
    "Google Chrome"
    "Google Drive"
    "Slack"
    "zoom.us"
    "Okta Verify"
    "Insiders Intranet"
    "Side IT Handshake"
  )
  local check_names=(
    "Checking Chrome"
    "Checking Drive"
    "Checking Slack"
    "Checking Zoom"
    "Checking Okta Verify"
    "Checking Side IT Apps"
    "Checking Side IT Apps"
  )

  for i in "${!app_names[@]}"; do
    update_list_item 8 "wait" "${check_names[$i]}"
    echo "${check_names[$i]}"
    sleep 3

    if [[ -d "${app_dir}${app_names[$i]}.app" ]]; then
      echo "Found: ${app_names[$i]}"
    else
      echo "Not found: ${app_names[$i]}"
      if [[ -z "${missing_apps}" ]]; then
        missing_apps="${app_names[$i]}"
      else
        missing_apps+=",${app_names[$i]}"
      fi
    fi
  done

  if [[ -n "${missing_apps}" ]]; then
    echo "Missing apps: ${missing_apps}"
    update_list_item 8 "pending" "App not found – notifying helpdesk"
    sudo jamf recon -room "Missing apps: ${missing_apps}"
    update_list_item 8 "success" "Done"
  else
    echo "All required apps are installed."
    update_list_item 8 "success" "All apps installed!"
    sleep 4
    update_list_item 8 "success" "Done"
  fi
}

#######################################
# FileVault dialogs and macOS upgrade
#######################################

fv_enable_dialog() {
  firstname_pull

  local title message timer web infobox

  title="Side, Inc New Device Setup Complete"
  message=$(
    cat <<EOF
The new device setup is complete!

As a final step, the device is going to automatically restart in 30 seconds.

At the next login you will be asked to "Enable" FileVault.

Click "Enable Now" and you are set!

**${first_name}Welcome to Side! We are happy to have you!**

Contact [helpdesk@side.com](mailto:helpdesk@side.com) or #it-support in Slack with any questions.
Thank you!
Side IT Helpdesk
EOF
  )
  timer=30
  web="https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png"
  infobox=$(
    cat <<EOF
__macOS Version__
${current_os_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Email__
[helpdesk@side.com](${dialog_hd_url})
EOF
  )

  "${dialog_bin}" \
    --title "${title}" \
    --titlefont "name=Arial-MT,size=23,colour=#FFC0CB" \
    --message "${message}" \
    --messagefont "name=Arial-MT,size=17,colour=#000000" \
    --icon "${web}" \
    --iconsize 500 \
    --background "${dialog_background}" \
    --timer "${timer}" \
    --width 70% \
    --height 50% \
    --blurscreen

  killall Dialog 2>/dev/null || true
}

installing_macos_notification() {
  firstname_pull

  local title message timer infobox

  title="Installing macOS ${macos_version}… Please wait"
  message=$(
    cat <<EOF
macOS ${macos_version} is being installed.

This process could take a while. Once done, the device will restart on its own
at which point the update will be complete.

**PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWER SOURCE SO IT IS NOT INTERRUPTED!**

**Please note – At your next login, you will be asked to ENABLE ENCRYPTION (see the image on the left) – click "Enable"!**

**${first_name}Welcome to Side! We are happy to have you!**

Contact [helpdesk@side.com](mailto:helpdesk@side.com) or #it-support in Slack with any questions.
Thank you!
Side IT Helpdesk
EOF
  )
  timer=$((60 * 45))
  infobox=$(
    cat <<EOF
__macOS Version__
${current_os_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Email__
[helpdesk@side.com](${dialog_hd_url})
EOF
  )

  "${dialog_bin}" \
    --title "${title}" \
    --titlefont "${dialog_title_font}" \
    --message "${message}" \
    --messagefont "name=Arial-MT,size=20,colour=#FFC0CB" \
    --banner "https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png" \
    --iconsize 250 \
    --video "youtubeid=Oj1RQ2X_-Xw" \
    --autoplay \
    --infobox "${infobox}" \
    --background "${dialog_background}" \
    --timer "${timer}" \
    --big \
    --button1text "none" \
    --button1disabled \
    --infotext "macOS ${macos_version} is being installed; this will take some time.\nContact helpdesk@side.com for assistance.\n${first_name}Welcome to Side!" \
    --blurscreen &
  dialog_install_pid=$!
}

install_macos() {
  echo "${user_pass}" | \
    "/Applications/Install macOS ${macos_name}.app/Contents/Resources/startosinstall" \
      --agreetolicense \
      --nointeraction \
      --user "${current_user}" \
      --stdinpass \
      --rebootdelay 30 &
  install_pid=$!

  wait "${install_pid}"
}

macos_install_fv_enable() {
  firstname_pull

  local title message timer web infobox

  title="Side, Inc New Device Setup Almost Complete"
  message=$(
    cat <<EOF
The new device setup is almost complete!

The macOS ${macos_version} installer is getting ready. This window will dismiss in 30 seconds and the update will initiate.
The installation should take about 15 to 30 minutes to complete. Once complete, the device will restart automatically.

Upon next login you will be asked to "Enable FileVault".

Click "Enable Now" and you are set!

**${first_name}Welcome to Side! We are happy to have you!**

Side IT Helpdesk
EOF
  )
  timer=30
  web="https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png"
  infobox=$(
    cat <<EOF
__macOS Version__
${current_os_version}

__Device Serial__
${mac_serial}

__Slack__
[#it-support](${dialog_slack_url})

__Email__
[helpdesk@side.com](${dialog_hd_url})
EOF
  )

  "${dialog_bin}" \
    --title "${title}" \
    --titlefont "name=Arial-MT,size=23,colour=#FFC0CB" \
    --message "${message}" \
    --messagefont "name=Arial-MT,size=16,colour=#FFC0CB" \
    --icon "${web}" \
    --iconsize 400 \
    --background "${dialog_background}" \
    --timer "${timer}" \
    --blurscreen \
    --height 70% \
    --infotext "Contact helpdesk@side.com for any assistance."

  killall Dialog 2>/dev/null || true

  echo "Launching macOS install notification and running startosinstall."
  installing_macos_notification
  install_macos
}

macos_update_check() {
  update_list_item 9 "wait" "Checking macOS version"
  sleep 2

  if [[ "${current_os_version}" == "${macos_version}" ]]; then
    echo "macOS on device (${current_os_version}) matches target (${macos_version})."
    update_list_item 9 "pending" "macOS up to date!"
    sleep 3
    update_list_item 9 "success" "Done"
    sleep 3

    killall Dialog 2>/dev/null || true
    fv_enable_dialog
    return
  fi

  echo "macOS on device (${current_os_version}) is older than target (${macos_version})."
  update_list_item 9 "wait" "Preparing update"
  sleep 3
  update_list_item 9 "wait" "Downloading ${macos_version} – please wait!"

  local macos_url macos_dir macos_pkg macos_inst_dir
  macos_url="https://swcdn.apple.com/content/downloads/${macos_dl_version}/InstallAssistant.pkg"
  macos_dir="/tmp/"
  macos_pkg="InstallAssistant.pkg"
  macos_inst_dir="/Applications/Install macOS ${macos_name}.app"

  echo "macOS download URL: ${macos_url}"

  if [[ ! -e "${macos_inst_dir}" ]]; then
    echo "Installer not found, downloading…"
    /usr/bin/curl -L "${macos_url}" -o "${macos_dir}${macos_pkg}"

    echo "Downloaded InstallAssistant, extracting…"
    update_list_item 9 "wait" "Extracting ${macos_version} – please wait!"

    sudo /usr/sbin/installer -pkg "${macos_dir}${macos_pkg}" -target /
    sleep 5

    sudo rm -f "${macos_dir}${macos_pkg}"
  else
    echo "Installer already present, skipping download."
  fi

  update_list_item 9 "wait" "Complete – verifying download."
  sleep 3

  if [[ -e "${macos_inst_dir}" ]]; then
    echo "Installer downloaded successfully; preparing install."
    update_list_item 9 "wait" "Success! Preparing install"
    sleep 3

    for i in 5 4 3 2 1; do
      update_list_item 9 "wait" "Install starting in ${i} second(s)"
      echo "Install starting in ${i} second(s)"
      sleep 1
    done

    killall Dialog 2>/dev/null || true
    echo "Launching FileVault enable pre-install dialog."
    macos_install_fv_enable
  else
    echo "Installer failed, submitting ticket and exiting."
    update_list_item 9 "pending" "Failed – notifying helpdesk"
    sudo jamf recon -room "Missing apps: macOS Update"

    killall Dialog 2>/dev/null || true
    fv_enable_dialog
  fi
}

#######################################
# Main execution
#######################################

# Full-screen Jamf helper while swiftDialog installs
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper \
  -windowType fs \
  -icon "/Library/Application Support/SideIT/initiatingSetup.png" \
  -fullScreenIcon &

install_swiftdialog
killall jamfHelper 2>/dev/null || true

# Initial checks
is_it_plugged_in
check_password

# Progress board
launch_progress_dialog

# Run setup phases
initialize
google_chrome
google_drive
slack_install
zoom_install
side_intranet_install
okta_verify_install
system_settings_apply
check_apps
macos_update_check

# Teardown (if we ever get here before reboot)
killall Dialog 2>/dev/null || true
kill "${caffeinate_pid}" 2>/dev/null || true

exit 0



------OG

#!/bin/bash

################################################################################
# Script Name: New Device Setup
# Version: 2.0
# Author: Travis Green
# Date: 2025-04
# Description: This script automates the setup process for new macOS devices,
#              including installing essential applications, configuring system
#              settings, and optionally upgrading macOS.
################################################################################


# wait until the Self Service process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Self Service..."
	setupProcess=$( /usr/bin/pgrep "Self Service" )
	sleep 3
done



#caffeinate
caffeinate -dims &


####### Assigned Parameter Variables ########
#############################################

#macOSVersion=15.4.1 #"$3" #15.4
#macOSName="Sequoia" #"$4" #Sequoia
	#https://swcdn.apple.com/content/downloads/${macos_dl_version}/InstallAssistant.pkg
#macos_dl_version="43/58/082-16524-A_VHRNGIT194/ksdv19dcxx90ja7nronzpb4kr4val0imsz" #"$5"


readonly macOSVersion="${4:-15.4.1}"  #15.4.1 #"$3" #15.4
readonly macOSName="${5:-Sequoia}"     #"Sequoia" #"$4" #Sequoia
readonly macos_dl_version="${6:-43/58/082-16524-A_VHRNGIT194/ksdv19dcxx90ja7nronzpb4kr4val0imsz}" # "$5"
readonly updatedDialogVersion="${7:-2.5.5}" # "$6" #Dialog version number - 2.5.5
readonly dialog_ver_dl="${8:-v2.5.5/dialog-2.5.5-4802.pkg}" # "$7" #v2.5.5/dialog-2.5.5-4802.pkg

#updatedDialogVersion=2.5.5 #"$6" #Dialog version number - 2.5.5
#dialog_ver_dl="v2.5.5/dialog-2.5.5-4802.pkg" #"$7" #v2.5.5/dialog-2.5.5-4802.pkg

dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/$dialog_ver_dl" #v2.5.5/dialog-2.5.5-4802.pkg

echo "Printing Parameters"
echo macOSVersion: $macOSVersion
echo macOSName: $macOSName
echo macos_dl_version $macos_dl_version
echo "Full link: https://swcdn.apple.com/content/downloads/${macos_dl_version}/InstallAssistant.pkg"
echo updatedDialogVersion $updatedDialogVersion
echo dialog_download_url $dialog_download_url
echo "Full link: https://github.com/swiftDialog/swiftDialog/releases/download/${dialog_ver_dl}"

echo "Proceeding with script..."
echo ""
echo ""



####### Assigned Dialog Variables ########
#############################################

dialog_bin="/usr/local/bin/dialog"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
report_file="/tmp/report.txt"
#delete report file just in case
sudo rm -rf $report_file


dialogDir='/usr/local/'
swiftDialogPKG="swiftDialog.pkg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#FFC0CB,size=30" #og: CE87C1



#######   Get user and device info   ########
#############################################	
																							
echo "Getting Logged In User"
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
uid=$(id -u "$currentUser")
echo "Logged in user: \"$currentUser\""

firstname_pull () {

# Get the currently logged-in console user
currentUser=$(echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }')

# Get the full real name of the current user
realname=$(dscl . -read /Users/"$currentUser" RealName 2>/dev/null | tail -n +2)

# Fallback if realname is empty or includes 'System Administrator'
if [[ -z "$realname" || "$realname" == *"System Administrator"* ]]; then
  first_name=""
else
  # Extract the first word (usually the first name)
  first_name=$(echo "$realname" | awk '{print $1}')
fi

# Output the result
echo $first_name
first_name="${first_name}, "

}

#pull first name first time
firstname_pull

#Device specific items
currentOSVersion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
######


#######   Install SwiftDialog   ########
#############################################	

installSwiftDialog () {
sleep 5
    if [ -f $dialog_bin ]; then
        echo "Dialog app found, checking version"
        dialogVersion=$(defaults read /Library/Application\ Support/Dialog/Dialog.app/Contents/Info CFBundleShortVersionString)
        echo "Dialog Version: "$dialogVersion

        if [ $dialogVersion != $updatedDialogVersion ]; then
            echo "Dialog not up to date, updating..."
            sudo /usr/bin/curl -L "$dialog_download_url" -o "$dialogDir$swiftDialogPKG"
            sudo /usr/sbin/installer -pkg "$dialogDir$swiftDialogPKG" -target /
            sleep 5
            sudo rm -r "$dialogDir$swiftDialogPKG"
        else
            echo "Dialog Version Correct, skipping update"
        fi
    else 
        echo "Dialog app not found, downloading and installing dialog"
        sudo /usr/bin/curl -L "$dialog_download_url" -o "$dialogDir$swiftDialogPKG"
        sudo /usr/sbin/installer -pkg "$dialogDir$swiftDialogPKG" -target /
        sleep 5
        sudo rm -r "$dialogDir$swiftDialogPKG"
    fi
}







#######   Check Power - Needs to be plugged in   ########
#############################################	

power_check_dialog () {
dTitle="Please Connect To A Power Source"
dMessage="Side's new device setup is about to start. 
This includes installing several applications and a full macOS update if necessary.

**Please connect the computer to a power source to ensure the device does not shut off.**

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
timer=120
web="https://i.pinimg.com/originals/59/df/95/59df95ecfb490ed3bab39a283ae7d8fa.gif"
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"

    # Show the dialog
    $dialog_bin --title "$dTitle" \
                --titlefont "$dialogTitleFont" \
                --message "$dMessage" \
                --messagefont "name=Arial-MT,size=20,colour=#000000" \
                --icon "$dialogIconDir" \
                --iconsize 250 \
                --infobox "$dInfoBox" \
                --webcontent "$web" \
                --background "$dialogBackGroundDir" \
				--timer "$timer" \
				--blurscreen
}


is_it_plugged_in () {
	# Function to check power source
	check_power_source() {
  	  pmset -g batt | grep "AC Power" &> /dev/null
   	 return $?

	
	}	

	launch_power_dialog () {
	
	
    
		# Loop until the power source is connected
		until check_power_source; do
		
			if pgrep -x "Dialog" > /dev/null; then
				echo "Dialog is running.. coninue"
			else
				echo "Dialog is not running"
				power_check_dialog & 
			fi
		
			
	   	 echo "Waiting for AC power..."
	    	 sleep 1
		 done
		 killall Dialog
	 }


# Initial check for power source
if check_power_source; then
    echo "The laptop is running on AC power."
else
    echo "The laptop is running on battery power."
power_check_dialog & 
launch_power_dialog

fi
}

###### END POWER CODE
############




#######   Get user Password for macOS Update   ########
#############################################	

### Get computer password for macOS update
check_password () {
	
passCheck=" "
passTitle="Attention: Computer Password Required"

until [ "$passCheck" == "PASSED" ];
do
	
dTitle=$passTitle
dMessage="In order to ensure that your MacBook is up to date and ready to go the Side Device Setup Process will automatically download and install the latest version of MacOS, currently $currentOSVersion
As part of the built-in MacOS security system, this MacOS upgrade will require your computer password.

**$wrong_pass**

In the field below, please type in the password you created a few minutes ago when you created your new account and click the **Start** button to begin the setup process.

Contact helpdesk@side.com or #it-support in Slack with any questions."
dButton1="Start"
dTimer=30 #turn into 60 for one minute
dPostponeTitle="Postpone until"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"


			postPoneConfirm=$(${dialog_bin} \
			    --title "$dTitle" \
				--titlefont "$dialogTitleFont" \
			    --message "$dMessage" \
				--messagefont "name=Arial-MT,size=20,colour=#000000" \
			    --icon "$dialogIconDir" \
				--iconsize 120 \
			    --button1text "$dButton1" \
				--helpmessage "$dHelp" \
				--helptitle "TITLE" \
				--textfield "Password",required,secure \
				--big \
				--infobox "$dInfoBox" \
				--background "$dialogBackGroundDir" \
				--blurscreen
			)
	

#uncomment below to show password in plain text
#echo "Confirm: "$postPoneConfirm
#echo ${postPoneConfirm:11}
userPass=${postPoneConfirm:11}

#use echo below to confirm - not printing for security
#echo userPass is $userPass
	
dscl . authonly "$currentUser" "$userPass" &> /dev/null; resultCode=$?
		if [ "$resultCode" -eq 0 ];then
	    	echo "Password Check: PASSED"
			passCheck="PASSED"
	    	# DO THE REST OF YOUR ACTIONS...
			passTitle="Computer Password Needed"

		else
	    	# Prompt for User Password
	    	echo "Password Check: WRONG PASSWORD"
	    	#wrongUserPassword
			passCheck="FAILED"
		
			wrong_pass="You have typed in an incorrect password. Try again!"
			passTitle="INCORRECT PASSWORD... TRY AGAIN!"
		fi


done

}


###### GET PASSWORD DONE


#####################
######################### INITIAL CHECKS
##Start setup
#install swift Dialog

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/initiatingSetup.png -fullScreenIcon & installSwiftDialog
killall jamfHelper


#Check Power
is_it_plugged_in


#Check User Password For macOS Update
check_password


######################### INITIAL CHECKS END
#####################




#######   Dialog with list of items - JSON   ########
#############################################	
#Pull first name
firstname_pull

# Path to the temporary JSON file for the dialog
#JSON_FILE=$(mktemp)

#JSON_FILE="/tmp/diagnostic_test.json"
JSON_FILE="/Library/Application Support/SideIT/diagnostic_test.json"

# Initialize JSON content with a list
cat <<EOF > "$JSON_FILE"
{
  "title": "Side Inc New Device Setup",
  "message": "${first_name}Your computer is being set up. Hang tight! Feel free to refill your coffee.\nNote* if there is a macOS update, it could take up to 45min more depeding on your internet speed.",
  "listitem": [
    {"title": "Gathering some things", "icon" : "/Library/Application Support/SideIT/ATTIcon.png", "status": "pending", "statustext": "Pending"},
	{"title": "Google Chrome",  "icon" : "https://upload.wikimedia.org/wikipedia/commons/8/87/Google_Chrome_icon_%282011%29.png","status": "pending", "statustext": "Pending"},
	{"title": "Google Drive",  "icon" : "https://icons.iconarchive.com/icons/marcus-roberto/google-play/512/Google-Drive-icon.png","status": "pending", "statustext": "Pending"},
	{"title": "Slack",  "icon" : "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d5/Slack_icon_2019.svg/2048px-Slack_icon_2019.svg.png","status": "pending", "statustext": "Pending"},
    {"title": "Zoom",  "icon" : "https://cdn.prod.website-files.com/5ee732bebd9839b494ff27cd/5eefe1691c86f247d55e8a8b_Zoom-App-Icon-2.webp","status": "pending", "statustext": "Pending"},
    {"title": "Side IT Apps",  "icon" : "/Library/Application Support/SideIT/finishing.png","status": "pending", "statustext": "Pending"},
	{"title": "Okta Verify Desktop",  "icon" : "https://plugins.miniorange.com/wp-content/uploads/2022/06/drupal-okta-verify.png","status": "pending", "statustext": "Pending"},
	{"title": "System Settings",  "icon" : "/Library/Application Support/SideIT/macosupdates.png","status": "pending", "statustext": "Pending"},
	{"title": "Checking Apps",  "icon" : "/System/Applications/App Store.app/Contents/Resources/AppIcon.icns","status": "pending", "statustext": "Pending"},
	{"title": "macOS Updates",  "icon" : "https://sm.pcmag.com/pcmag_uk/review/a/apple-maco/apple-macos-sequoia_h3sb.png","status": "pending", "statustext": "Pending"},
  ]
}
EOF

dInfoBox="__Current macOS:__ $currentOSVersion\n\n"
dInfoBox+="__Update To:__\n$macOSVersion\n\n"
dInfoBox+="__Device Serial__\n$macSerial\n\n"
dInfoBox+="__Slack__\n[#it-support]($dialogSlackURL)\n\n"
dInfoBox+="__Support Ticket__\n[helpdesk@side.com]($dialogHDURL)"


# Launch Swift Dialog in the background
$dialog_bin --jsonfile "$JSON_FILE" --infobox "$dInfoBox" --big  --ontop --progress --icon "$dialogIconDir" --background "$dialogBackGroundDir" --blurscreen --messagefont "name=Arial-MT,size=20,colour=#000000" --titlefont "$dialogTitleFont" --button1text " " --button1disabled &
DIALOG_PID=$!

# Trap to clean up JSON and dialog process
trap "rm -f $JSON_FILE; kill $DIALOG_PID 2>/dev/null" EXIT

# Function to update the list dynamically
update_list_item() {
  local index=$1
  local status=$2
  local status_text=$3

  # Update the list item dynamically using the advanced syntax
  echo "listitem: index: $index, status: $status, statustext: $status_text" >> /var/tmp/dialog.log
}






initialize () { #update_list_item 0
  update_list_item 0 "wait" "Warming up..."
  
  echo "What to do, to be determined"
  
  sleep 3
  
  update_list_item 0 "success" "Done"

}

google_chrome () { #update_list_item 1
    update_list_item 1 "wait" "Downloading Chrome"
	echo "Downloading Chrome"
	url='https://dl.google.com/chrome/mac/universal/stable/CHFA/googlechrome.dmg '
	dmgfile="googlechrome.dmg"
	volname="Google Chrome"
	logfile="/Library/Logs/GoogleChromeInstallScript.log"

	/bin/echo "--" >> ${logfile}
	/bin/echo "`date`: Downloading latest version." >> ${logfile}
	/usr/bin/curl -s -o /tmp/${dmgfile} ${url}
	/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
	/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse -quiet
	
	sleep 2
	
	echo "Installing Chrome"
	update_list_item 1 "wait" "Installing Chrome"
	
	/bin/echo "`date`: Installing..." >> ${logfile}
	ditto -rsrc "/Volumes/${volname}/Google Chrome.app" "/Applications/Google Chrome.app"
	/bin/sleep 10
	/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
	/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
	/bin/sleep 10
	/bin/echo "`date`: Deleting disk image." >> ${logfile}
	/bin/rm /tmp/"${dmgfile}"
	
	 
	 sleep 2
  
    update_list_item 1 "success" "Done"
}


google_drive () { #update_list_item 2

  update_list_item 2 "wait" "Downloading Drive"
  echo "Downloading Drive"
  #Set parameters
  URL="https://dl.google.com/drive-file-stream/GoogleDrive.dmg"
  DMG='GoogleDrive.dmg'
  PKG='GoogleDrive.pkg'
  DIRDMG='/tmp/'$DMG
  DIRPKG='/tmp/'$PKG

  #download
  /usr/bin/curl -L -o $DIRDMG ${URL} 
  sleep 20


  #mount and move PKG
  /usr/bin/hdiutil attach /tmp/${DMG} -nobrowse -quiet

  ditto -rsrc "/Volumes/Install Google Drive/GoogleDrive.pkg" $DIRPKG
  /bin/sleep 10

update_list_item 2 "wait" "Installing Drive"
echo "Installing Drive"

  #install PKG
  sudo installer -pkg $DIRPKG -tgt / -verbose


  #Cleanup
  /usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "Install Google Drive" | awk '{print $1}') -quiet
  /bin/sleep 3

  /bin/rm /tmp/"${DMG}"

  /bin/rm /tmp/"${PKG}"
	
	sleep 2
  
  update_list_item 2 "success" "Done"
  


}

slack () { #update_list_item 3

    update_list_item 3 "wait" "Downloading Slack"
	echo "Dowloading Slack"
	
	#set directories
	echo "Setting directories..."
	finalURL=$(curl https://slack.com/ssb/download-osx -s -L -I -o /dev/null -w '%{url_effective}')
	dmgfile="Slack.dmg"
	dir=/tmp/$dmgfile

	#download file
	echo "Downloading..."
	sudo /usr/bin/curl --retry 3 -L "$finalURL" -o $dir
	
	
	sleep 3
	update_list_item 3 "wait" "Installing Slack"
	echo "Installing Slack"
	
	#mount dmg
	echo "Mounting dmg..."
	/usr/bin/hdiutil attach $dir -nobrowse -quiet

	#copy app over
	echo "Coping App to Applications folder..."
	ditto -rsrc "/Volumes/Slack/Slack.app" "/Applications/Slack.app"

	#sleep 5
	echo "Sleep 5"
	sleep 5

	#unmount dmg
	echo "Unmounting dmg...."
	/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "Slack" | awk '{print $1}') -quiet

	#delete temp file
	echo "Cleaning up..."
	sudo rm -Rf $dir
	
	
	
	
    update_list_item 3 "success" "Done"
	

}

zoom () { #update_list_item 4
  update_list_item 4 "wait" "Downloading Zoom"
	echo "Downloading Zoom"
	#Downloading and installing Zoom

url="https://zoom.us/client/latest/ZoomInstallerIT.pkg"

#setting directories

pkgfile='Zoom.pkg'
dir='/tmp/'$pkgfile


#Downloading PKG
echo "Downloading..."
/usr/bin/curl -L -o $dir ${url} 

echo "Sleep 5"
#Small break
Sleep 5
  
  
	update_list_item 4 "wait" "Installing Zoom"
	echo "Installing..."
	#Installing PKG
	sudo installer -pkg $dir -tgt / -verbose

	echo "Sleep 5"
	#Give it a break
	sleep 5

	#Delete the temp file
	echo "Cleanup..."
	sudo rm -Rf $dir

	#Close Zoom app
	#echo "Closing Zoom app..."
	#killall zoom.us
	
	echo "Creating PLIST"
	#This creates a PLIST that is placed in /Library/Managed Preferences.
	#on install of zoomIT.pkg, it then opens the app and forces the user to log in VIA SSO
	#FB and Google are disabled for login options

update_list_item 4 "wait" "Zoom Settings"

	echo "Creating PLIST..."
	#Creating PLIST
	cat > /Library/Preferences/us.zoom.config.plist <<EOF
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	<dict>
		<key>nogoogle</key>
		<true/>
		<key>nofacebook</key>
		<true/>
		<key>zDisableVideo</key>
		<true/>
		<key>zAutoJoinVoip</key>
		<true/>
		<key>zAutoSSOLogin</key>
		<true/>
		<key>zSSOHost</key>
		<string>sideinc.zoom.us</string>
		<key>EnableShareVideo</key>
		<false/>
		<key>zRemoteControlAllApp</key>
		<true/>
	    <key>zAutoFullScreenWhenViewShare</key>
		<false/>
		<key>zAutoFitWhenViewShare</key>
		<true/>
		<key>zAutoUpdate</key>
		<true/>
		<key>EnableSilentAutoUpdate</key>
		<true/>
	</dict>
	</plist>

EOF
	echo "PLIST Created..."
	


  

  # Properly pass the string to the function
  update_list_item 4 "success" "Done"
  

}

side_intranet () { #update_list_item 5
  update_list_item 5 "wait" "Downloading Side IT Apps"
  
	
	sleep 3
	update_list_item 5 "wait" "Installing Side IT Apps"
	sudo jamf policy -event inSiderIntranet
	sudo jamf policy -event side_it_handshake
	sleep 3
  
  update_list_item 5 "success" "Done"
  


}

okta_verify () { #update_list_item 6

    update_list_item 6 "wait" "Installing Okta Verify"
	
	sudo jamf policy -event okta_verify
	sleep 3
  
    update_list_item 6 "success" "Done"
	

}

system_settings () { #update_list_item 7
	
	update_list_item 7 "wait" "Setting Dock"
	
	echo "Dock"
	sudo jamf policy -event modifyDock 
	sleep 3
	
	update_list_item 7 "wait" "Setting Device Name"
	
	echo "Device Name"
	sudo jamf policy -event mbpname
	sleep 3
	
	update_list_item 7 "wait" "Assigning Device"
	echo "Upload user"
	sudo jamf policy -event uploadUser
	sleep 3
	
	update_list_item 7 "wait" "Turning on Disk Encryption"
	echo "Enable FV"
	sudo jamf policy -event fvenable
	sleep 3
	
	
	update_list_item 7 "success" "Done"
	


}

check_apps () { #update_list_item 8
    update_list_item 8 "wait" "Checking apps are installed"
	sleep 2
	


missing_apps=""
app_dir="/Applications/"
app_names=("Google Chrome" "Google Drive" "Slack" "zoom.us" "Okta Verify" "Insiders Intranet" "Side IT Handshake")
check_names=("Checking Chrome" "Checking Drive" "Checking Slack" "Checking Zoom" "Checking Okta Verify" "Checking Side IT Apps" "Checking Side IT Apps")


for i in "${!app_names[@]}"; do
  update_list_item 8 "wait" "${check_names[$i]}"
  echo "Checking " "${check_names[$i]}"
  sleep 3

  if [ -d "${app_dir}${app_names[$i]}.app" ]; then
    echo "Found: " "${app_names[$i]}"
  else
    if [ -z "$missing_apps" ]; then
      missing_apps="${app_names[$i]}"
	  echo "Not Found: " "${app_names[$i]}"
    else
      missing_apps="$missing_apps,${app_names[$i]}"
    fi
  fi
done


# Output the missing apps and final status
if [ -n "$missing_apps" ]; then
  echo "Missing apps: $missing_apps"
  update_list_item 8 "pending" "App not found- Notifying helpdesk"
  
  sudo jamf recon -room "Missing apps: ${missing_apps}"
  
  #sleep 10
  update_list_item 8 "success" "Done"
  
else
  echo "All required apps are installed."
  update_list_item 8 "success" "All apps installed!"
  sleep 4
  update_list_item 8 "success" "Done"
  
fi


}



#### FV Dialog
fv_enable_dialog () {
#pull first name
firstname_pull


dTitle="Side, Inc New Device Setup Complete"
dMessage="The new device set is complete!\n

As a final step, the device is going to automatically restart in 30 seconds.

At the next login you will be asked to \"Enable\" FileVault.

Click \"Enable Now\" and you are set!

**${first_name}Welcome to Side! We are happy to have you!**


Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
timer=30
web="/Library/Application Support/SideIT/filevaultenable.png"
web="https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png"
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"

    # Show the dialog
	fv_alert=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "name=Arial-MT,size=23, colour=#FFC0CB" \
	    --message "$dMessage" \
		--messagefont "name=Arial-MT,size=17,colour=#000000" \
	    --icon "$web" \
		--iconsize 500 \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--background "$dialogBackGroundDir" \
		--timer "$timer" \
		--width 70% \
		--height 50% \
        --blurscreen

	)
				
	killall Dialog
				
				
}










########## MACOS UPDATE
installing_macOS_notification () {
#pull first name
firstname_pull
    
dTitle="Installing macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is being installed.

This process could take a while.\n Once done, the device will restart on its own
at which point the update will be complete.

**PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWERSOURCE SO IT IS NOT INTERRUPTED!**


**Please note - At your next login, you will be asked to ENABLE ENCRYPTION (see the image on the left )- CLICK \"ENABLE!\"**

**${first_name}Welcome to Side! We are happy to have you!**

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialog_icon_dir"
#OG web="https://cdn.osxdaily.com/wp-content/uploads/2019/02/brooklyn-sceensaver-animated-pedrommcarrasco-github.gif"
#web="https://www.youtube.com/watch?v=_TNV61Qy1K4"
timer=2700 #60*45=2700
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"


			updateNowAlert=$(${dialog_bin} \
			    --title "$dTitle" \
				--titlefont "$dialogTitleFont" \
			    --message "$dMessage" \
				--messagefont "name=Arial-MT,size=20,colour=#FFC0CB" \
			    --banner "https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png" \
				--iconsize 250 \
				--helpmessage "$dHelp" \
				--helptitle "TITLE" \
				--video youtubeid=Oj1RQ2X_-Xw \
				--autoplay \
			    --infobox "$dInfoBox" \
				--background "$dialogBackGroundDir" \
				--timer "$timer" \
				--big \
				--button1text "none" \
				--button1disabled \
				--infotext "macOS $macOSVersion is being installed, this process will take some time.\nContact helpdesk@side.com for any assistance.\n${first_name}Welcome to Side!" \
	            --blurscreen
	
	
			)
		
			 dialogInstallPID=$! # Capture the dialog process ID
}

install_macOS() {
	echo $userPass | /Applications/Install\ macOS\ $macOSName.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass --rebootdelay 30
    
    # Capture the PID of the download process
    installPID=$!
	echo "Started install with PID $downloadPID"

    # Wait for the download to finish
    wait $installPID
}



macos_install_fv_enable () {
#first name pull
firstname_pull


dTitle="Side, Inc New Device Setup Almost Complete"
dMessage="The new device set is almost complete!\n

The macOS ${macOSVersion} installer is getting ready. This window will dismiss in 30 seconds and the update will initiate.\n
The installation should take about 15 to 30 minutes to complete. Once complete, the device will restart automatically.

Upon next login you will be asked to \"Enable FileVault\".

Click \"Enable Now\" and you are set!

**${first_name}Welcome to Side! We are happy to have you!**

Side IT Helpdesk"
timer=30
web="/Library/Application Support/SideIT/filevaultenable.png"
web="https://support.ntiva.com/hc/article_attachments/8035847302157/FileVault-Prompt.png"
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"

    # Show the dialog
	fv_alert=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "name=Arial-MT,size=23, colour=#FFC0CB" \
	    --message "$dMessage" \
		--messagefont "name=Arial-MT,size=16,colour=#FFC0CB" \
	    --icon "$web" \
		--iconsize 400 \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--background "$dialogBackGroundDir" \
		--timer "$timer" \
        --blurscreen \
		--height 70% \
		--infotext "Contact helpdesk@side.com for any assistance." 

	)
				
	killall Dialog
	echo "Killing FV dialog. Launching macOS install dialog and installing macOS"
	installing_macOS_notification & install_macOS
				
				
}



macos_update_check () { #update_list_itel 9
    update_list_item 9 "wait" "Checking macOS version"
	sleep 2
	
	
	if [[ "$currentOSVersion" == "$macOSVersion" ]]; then
		echo "macOS on Device: $currentOSVersion | Latese macOS Version: $macOSVersion - MATCH!"
		update_list_item 9 "pending" "macOS Up To Date!"
		sleep 3
		update_list_item 9 "success" "Done"
		sleep 3
		
		killall Dialog
		fv_enable_dialog
		

		
	else
	  
	  echo "macOS on Device: $currentOSVersion | Latese macOS Version: $macOSVersion - Out of date!"
  	  update_list_item 9 "wait" "Preparing Update"
 	  sleep 3
	  update_list_item 9 "wait" "Downloading ${macOSVersion}-Please Wait!"
	    
		macOSURL="https://swcdn.apple.com/content/downloads/${macos_dl_version}/InstallAssistant.pkg"
	
		echo "MacOS Download URL: "$macOSURL
	
		#https://swcdn.apple.com/content/downloads/30/63/062-58676-A_ECWQ492BNE/hrlydsxfk837el7k95venauqmn8ruizw3e/InstallAssistant.pkg
		macOSDir="/tmp/"
		macOSPKG="InstallAssistant.pkg"
	
		#Check for Installer
		macOSInsDir="/Applications/Install macOS ${macOSName}.app"

		if [ -e "$macOSInsDir" ]; then
			echo "Installer found, proceeding..."
            
		else
			echo "Installer not found, downloading"
		echo Downloading $macOSVersion
	
	
	
		#downloading InstallAssistant.pkg 
		curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
		
		
	
		echo "Downloaded InstallAssistant, extracting..."
		#install - extract "Install macOS $name.app"
		update_list_item 9 "wait" "Extracting ${macOSVersion}-Please Wait!"
		 sudo /usr/sbin/installer -pkg "${macOSDir}${macOSPKG}" -target /
	
		sleep 5
	
		#Cleanup - remove InstallAssistant.pkg
		sudo rm -rf "${macOSDir}${macOSPKG}"
		#
	
	fi #fi for primary installer check
	
		update_list_item 9 "wait" "Complete - verifying download."
		sleep 3
		#verifying install
		if [ -e "$macOSInsDir" ]; then
			echo "Installer downloaded successfully, proceeding...."
			update_list_item 9 "wait" "Success! Preparing install"
			sleep 3

			for i in 5 4 3 2 1; do
			  update_list_item 9 "wait" "Install starting in $i second(s)"
			  echo "Install starting in $i second(s)"
			  sleep 1
			done
			
			killall Dialog
            echo "JSON Dialog Killed"
			echo "Launching FV alert before macOS install"
			macos_install_fv_enable
			
		
		else
			echo "Installer failed, submitting ticket and exiting script"
			update_list_item 9 "pending" "Failed- Notifying helpdesk"
			sudo jamf recon -room "Missing apps: ${missing_apps}, macOS Update"
			
			killall Dialog
			fv_enable_dialog
			#launch filevault dialog
			
		fi #fi for installer check after download
		
	    
	fi
	
	
	

	
}







# Execute the installation functions
initialize #update_list_item 0

#Google Chrome
google_chrome #update_list_item 1

#Google Drive
google_drive #update_list_item 2

#Slack
slack #update_list_item 3

#Zoom
zoom #update_list_item 4

#Intranet
side_intranet #update_list_item 5

#Okta Verify
okta_verify #update_list_item 6

#System Settings
system_settings #update_list_item 7

#Check Apps
check_apps #update_list_item 8

#macOS Update Check
macos_update_check #update_list_itel 9




#after macOS Installer
until ! pgrep -x -P $processPID > /dev/null; do
    echo "Process $processPID is still running..."
    sleep 5  # Check every 5 seconds
done
kill $dialogInstallPID
killall Dialog



# End caffeinate process - Goodbye!
killall caffeinate
