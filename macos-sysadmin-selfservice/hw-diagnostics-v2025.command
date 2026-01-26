#!/usr/bin/env bash
#
# Script Name: Side Hardware Diagnostic Test
# Author: Travis Green
# Date: 2025-01-02
#
# Description:
#   Runs an interactive hardware and readiness diagnostic using swiftDialog:
#     - Side IT password gate
#     - Power/charging check
#     - Battery health and cycle count
#     - CPU and SSD read/write tests
#     - Network reachability and speed test
#     - Bluetooth radio basic validation
#     - USB-C ports presence check
#     - Speaker and microphone sanity checks
#     - iCloud sign‑in state
#   Produces a text report and, if iCloud is signed out and everything looks good,
#   optionally flags the Mac as ready to erase in Jamf and opens System Settings.
#

set -euo pipefail

#######################################
# Globals
#######################################

DIALOG_PATH="/usr/local/bin/dialog"
dialog_background="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialog_icon_dir="/Library/Application Support/SideIT/ATTIcon.png"

report_file="/tmp/side_hw_diagnostic_report.txt"
JSON_FILE="/tmp/diagnostic_test.json"

power_timer=120
side_it_password="${4:-}"

# Shared state used across functions
power_status="Unknown"
power_status_report="Unknown"
power_mark="pending"
all_good_icloud="no"
tempfile=""
ssd_pkg_path=""

#######################################
# Utility helpers
#######################################

current_console_user() {
  stat -f '%Su' /dev/console
}

safe_rm() {
  local path="$1"
  [[ -e "${path}" ]] && sudo rm -rf "${path}"
}

log_section() {
  # Convenience helper to make report more readable.
  # Usage: log_section "Battery"
  printf '**%s:**\n' "$1" >>"${report_file}"
}

#######################################
# Password gate
#######################################

check_password() {
  local pass_check="FAILED"
  local dialog_output returncode

  if [[ -z "${side_it_password}" ]]; then
    echo "Side IT password parameter (4) is empty. Aborting."
    exit 1
  fi

  while [[ "${pass_check}" != "PASSED" ]]; do
    local dTitle dMessage dButton1 dButton2 dHelp

    dTitle="Side IT Password Required"
    dMessage=$(
      cat <<EOF
Due to high risk, this policy is password‑protected by Side IT Helpdesk.

Only run this under Side IT supervision.

Please enter the policy password. If you do not have it, please contact helpdesk@side.com.
EOF
    )
    dButton1="Start"
    dButton2="Cancel"
    dHelp="This notification is launched automatically by Side IT Helpdesk.\nPlease contact helpdesk@side.com or #it-support in Slack with any questions or concerns."

    dialog_output="$(
      "${DIALOG_PATH}" \
        --title "${dTitle}" \
        --titlefont "name=Arial-MT,colour=#CE87C1,size=30" \
        --message "${dMessage}" \
        --messagefont "name=Arial-MT,size=18" \
        --icon "${dialog_icon_dir}" \
        --iconsize 120 \
        --button1text "${dButton1}" \
        --button2text "${dButton2}" \
        --helpmessage "${dHelp}" \
        --helptitle "TITLE" \
        --textfield "Password",required,secure \
        --big \
        --background "${dialog_background}"
    )"
    returncode=$?

    echo "Raw password dialog output: ${dialog_output}"

    case "${returncode}" in
      0)
        echo "Pressed Button 1: Start"
        if [[ "${dialog_output}" == "Password : ${side_it_password}" ]]; then
          echo "Password Check: PASSED"
          pass_check="PASSED"
        else
          echo "Password Check: FAILED"
          pass_check="FAILED"
        fi
        ;;
      2)
        echo "Pressed Button 2: Cancel"
        exit 0
        ;;
      *)
        echo "Password dialog error: exit code ${returncode}"
        exit 1
        ;;
    esac
  done

  killall Dialog 2>/dev/null || true
}

#######################################
# Power dialog and status
#######################################

check_power_source() {
  pmset -g batt | grep -q "AC Power"
}

power_check_dialog() {
  local dMessage web

  dMessage=$(
    cat <<EOF
In order to complete the diagnostic test, the device must be connected to a power source.

Please ensure the computer is connected to a power source to proceed with the test.
If a power source is not connected within the next two minutes, this alert will automatically dismiss, and the charge test will not be performed.
EOF
  )

  web="https://i.pinimg.com/originals/59/df/95/59df95ecfb490ed3bab39a283ae7d8fa.gif"

  "${DIALOG_PATH}" \
    --title "Initializing. Power Source Connection Required" \
    --titlefont "name=Arial-MT,colour=#CE87C1,size=30" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=15" \
    --icon "${dialog_icon_dir}" \
    --iconsize 250 \
    --webcontent "${web}" \
    --background "${dialog_background}" \
    --timer "${power_timer}" \
    --moveable \
    --ontop
}

launch_power_dialog() {
  power_check_dialog &
  local start_time
  start_time="$(date +%s)"

  while true; do
    if check_power_source; then
      echo "Power source connected. Dismissing dialog."
      killall Dialog 2>/dev/null || true
      power_status="Good"
      power_status_report="Good – Charge when plugged in."
      power_mark="success"
      break
    fi

    local now
    now="$(date +%s)"

    if (( now - start_time >= power_timer )); then
      echo "Power timer expired. Dismissing dialog."
      killall Dialog 2>/dev/null || true
      power_status="Unknown❗"
      power_status_report="Unknown❗ – Charger not plugged in or damaged. Please verify manually."
      power_mark="failed"
      break
    fi

    echo "Power not connected, waiting… ${now} seconds since epoch."
    sleep 1
  done
}

power_check_launch() {
  if check_power_source; then
    echo "The laptop is running on AC power."
    power_status="Good"
    power_status_report="Good – Device was already charging."
    power_mark="success"
  else
    echo "The laptop is running on battery power, launching power dialog."
    launch_power_dialog
  fi
}

#######################################
# Progress dashboard (swiftDialog JSON)
#######################################

init_dialog_json() {
  cat <<EOF >"${JSON_FILE}"
{
  "title": "Side Inc Hardware Diagnostic Test",
  "message": "Diagnostic test running. This won't take long.",
  "listitem": [
    { "title": "Initializing",    "status": "pending", "statustext": "Pending" },
    { "title": "Charger",        "status": "pending", "statustext": "Pending" },
    { "title": "Battery",        "status": "pending", "statustext": "Pending" },
    { "title": "CPU",            "status": "pending", "statustext": "Pending" },
    { "title": "SSD",            "status": "pending", "statustext": "Pending" },
    { "title": "Network",        "status": "pending", "statustext": "Pending" },
    { "title": "Bluetooth",      "status": "pending", "statustext": "Pending" },
    { "title": "USB Ports",      "status": "pending", "statustext": "Pending" },
    { "title": "Speakers",       "status": "pending", "statustext": "Pending" },
    { "title": "Microphone",     "status": "pending", "statustext": "Pending" },
    { "title": "iCloud Status",  "status": "pending", "statustext": "Pending" },
    { "title": "Building Report","status": "pending", "statustext": "Pending" }
  ]
}
EOF
}

launch_progress_dialog() {
  "${DIALOG_PATH}" \
    --jsonfile "${JSON_FILE}" \
    --infobox \
    --big \
    --ontop \
    --moveable \
    --progress \
    --background "${dialog_background}" \
    --icon "${dialog_icon_dir}" \
    --button1text "Cancel" &
  DIALOG_PID=$!

  trap 'rm -f "'"${JSON_FILE}"'"; kill ${DIALOG_PID} 2>/dev/null || true' EXIT
}

update_list_item() {
  local index="$1"
  local status="$2"
  local status_text="$3"

  # This logs the intended update; to fully integrate with swiftDialog,
  # you can use its "command file" input to drive dynamic updates.
  echo "listitem: index: ${index}, status: ${status}, statustext: ${status_text}" >>/var/tmp/side_diagnostic_dialog.log
}

#######################################
# Export / report dialog
#######################################

export_report_dialog() {
  echo "Launching export report dialog…"

  local print_report
  print_report="$(cat "${report_file}")"

  local dTitle dMessage timer dialogSelection returncode date_str serial

  dTitle="Side Inc Diagnostic Test"
  dMessage=$(
    cat <<EOF
Click **Export** to save a text copy of the report.

This dialog will auto‑dismiss in 5 minutes.

**For extra caution, please test anything concerning manually.**

${print_report}
EOF
  )
  timer=300

  dialogSelection="$(
    "${DIALOG_PATH}" \
      --title "${dTitle}" \
      --message "${dMessage}" \
      --messagefont "name=Arial-MT,size=13" \
      --icon "${dialog_icon_dir}" \
      --iconsize 120 \
      --button1text "Exit" \
      --button2text "Export" \
      --background "${dialog_background}" \
      --moveable \
      --timer "${timer}"
  )"

  returncode=$?

  case "${returncode}" in
    0)
      echo "Pressed Button 1: Exit"
      ;;
    2)
      echo "Pressed Button 2: Export"
      date_str="$(date '+%Y-%m-%d_%H-%M-%S')"
      serial="$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')"
      cp "${report_file}" "${HOME}/Desktop/${date_str} - ${serial}.txt"
      ;;
    *)
      echo "Export dialog error: exit code ${returncode}"
      ;;
  esac

  safe_rm "${report_file}"
  killall Dialog 2>/dev/null || true
}

#######################################
# Test steps
#######################################

initialize_step() {
  update_list_item 0 "progress" "Initializing…"
  echo "Downloading file for SSD test…"

  local url
  url="https://api.textmate.org/downloads/release?os=10.12"
  ssd_pkg_path="/tmp/ssd_test.pkg"

  /usr/bin/curl -L -o "${ssd_pkg_path}" "${url}"

  tempfile="${ssd_pkg_path}"

  sleep 3
  update_list_item 0 "success" "Done"
}

power_check_step() {
  update_list_item 1 "progress" "Getting charging information…"

  log_section "Power"
  printf '> Condition: %s\n\n\n' "${power_status_report}" >>"${report_file}"

  update_list_item 1 "${power_mark}" "${power_status}"
}

battery_condition_step() {
  update_list_item 2 "progress" "Running battery tests…"
  log_section "Battery"

  echo "Getting battery cycle count…"
  local battery_cycle_count
  battery_cycle_count="$(system_profiler SPPowerDataType | awk -F': ' '/Cycle Count/ {print $2}')"
  printf '> Cycle Count: %s\n' "${battery_cycle_count}" >>"${report_file}"

  echo "Getting battery condition…"
  local battery_condition
  battery_condition="$(system_profiler SPPowerDataType | awk -F': ' '/Condition/ {print $2}')"
  printf '> Condition: %s\n' "${battery_condition}" >>"${report_file}"

  local battery_result
  battery_result="${battery_condition} * Cycle Count ${battery_cycle_count}"
  echo "Battery results: ${battery_result}"

  update_list_item 2 "success" "${battery_result}"

  printf '\n\n' >>"${report_file}"
}

cpu_condition_step() {
  update_list_item 3 "progress" "Running CPU tests…"
  log_section "CPU"

  local cpu_temp_file="${tempfile:-/tmp/cpu_test.tmp}"
  local block_size="1M"
  local block_count=1024

  convert_to_gb_per_sec() {
    local raw="$1"
    local clean
    clean="$(echo "${raw}" | tr -cd '[:digit:].')"
    printf '%.2f\n' "$(echo "${clean} / 1073741824" | bc -l)"
  }

  echo "Testing CPU write speed…"
  local write_output cpu_write_speed cpu_write_speed_gb
  write_output="$(dd if=/dev/zero of="${cpu_temp_file}" bs="${block_size}" count="${block_count}" oflag=direct 2>&1 || true)"
  echo "Raw write output: ${write_output}"
  cpu_write_speed="$(echo "${write_output}" | awk '/bytes transferred/ {print $(NF-1)}')"
  cpu_write_speed_gb="$(convert_to_gb_per_sec "${cpu_write_speed}")"
  echo "Write speed: ${cpu_write_speed_gb} GB/s"

  echo "Testing CPU read speed…"
  local read_output cpu_read_speed cpu_read_speed_gb
  read_output="$(dd if="${cpu_temp_file}" of=/dev/null bs="${block_size}" count="${block_count}" iflag=direct 2>&1 || true)"
  echo "Raw read output: ${read_output}"
  cpu_read_speed="$(echo "${read_output}" | awk '/bytes transferred/ {print $(NF-1)}')"
  cpu_read_speed_gb="$(convert_to_gb_per_sec "${cpu_read_speed}")"
  echo "Read speed: ${cpu_read_speed_gb} GB/s"

  printf '> Read Speed: %s GB/s\n' "${cpu_read_speed_gb}" >>"${report_file}"
  printf '> Write Speed: %s GB/s\n\n\n' "${cpu_write_speed_gb}" >>"${report_file}"

  update_list_item 3 "success" "Read ${cpu_read_speed_gb} GB/s * Write ${cpu_write_speed_gb} GB/s"
}

ssd_condition_step() {
  update_list_item 4 "progress" "Running SSD tests…"
  log_section "SSD"

  local tempfile_path="/tmp/ssd_test.bin"

  bytes_to_mb() { echo "scale=2; $1 / 1048576" | bc; }
  mb_to_gb()   { echo "scale=2; $1 / 1024" | bc; }

  echo "Testing SSD write speed…"
  local write_output write_bytes write_speed_mb write_speed_gb
  write_output="$(dd if=/dev/zero of="${tempfile_path}" bs=1G count=1 oflag=direct 2>&1 || true)"
  write_bytes="$(echo "${write_output}" | awk '/bytes transferred/ {gsub(/[()]/,"",$(NF-1)); print $(NF-1)}')"
  write_speed_mb="$(bytes_to_mb "${write_bytes}")"
  write_speed_gb="$(mb_to_gb "${write_speed_mb}")"
  printf '> Write Speed: %s GB/second\n\n' "${write_speed_gb}" >>"${report_file}"

  sync

  echo "Testing SSD read speed…"
  local read_output read_bytes read_speed_mb read_speed_gb
  read_output="$(dd if="${tempfile_path}" of=/dev/null bs=1G count=1 iflag=direct 2>&1 || true)"
  read_bytes="$(echo "${read_output}" | awk '/bytes transferred/ {gsub(/[()]/,"",$(NF-1)); print $(NF-1)}')"
  read_speed_mb="$(bytes_to_mb "${read_bytes}")"
  read_speed_gb="$(mb_to_gb "${read_speed_mb}")"
  printf '> Read Speed: %s GB/second\n' "${read_speed_gb}" >>"${report_file}"

  local ssd_results
  ssd_results="Read ${read_speed_gb}GB/s * Write ${write_speed_gb}GB/s"
  echo "SSD test results: ${ssd_results}"

  update_list_item 4 "success" "${ssd_results}"

  printf '\n\n' >>"${report_file}"
}

network_condition_step() {
  update_list_item 5 "progress" "Running network tests…"
  log_section "Network"

  local wifi_status download_speed upload_speed

  if ping -c 4 8.8.8.8 >/dev/null 2>&1; then
    wifi_status="Good"
    sleep 2

    local speed_test
    speed_test="$(
      curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 2>/dev/null || true
    )"

    download_speed="$(echo "${speed_test}" | awk '/Download/ {print $2, $3}')"
    upload_speed="$(echo "${speed_test}" | awk '/Upload/ {print $2, $3}')"

    if [[ -z "${download_speed}" || -z "${upload_speed}" ]]; then
      download_speed="Download unavailable❗"
      upload_speed="Upload unavailable❗"
    fi
  else
    wifi_status="Bad❗"
    download_speed="No connection❗"
    upload_speed="NA❗"
  fi

  local show_result
  show_result="DN:${download_speed} * UP:${upload_speed}"
  echo "Network results: ${show_result}"

  printf '> Download Speed: %s\n' "${download_speed}" >>"${report_file}"
  printf '> Upload Speed: %s\n\n\n' "${upload_speed}" >>"${report_file}"

  update_list_item 5 "success" "${show_result}"
}

bt_condition_step() {
  update_list_item 6 "progress" "Running Bluetooth tests…"
  log_section "Bluetooth"

  local bt_status

  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found; installing…"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true
    export PATH="/opt/homebrew/bin:/usr/local/bin:${PATH}"
  fi

  if ! command -v blueutil >/dev/null 2>&1; then
    echo "Installing blueutil…"
    brew install blueutil || true
  fi

  if command -v blueutil >/dev/null 2>&1; then
    local bluetooth_status
    bluetooth_status="$(blueutil -p)"

    if [[ "${bluetooth_status}" -eq 1 ]]; then
      echo "Bluetooth is already on and working."
      bt_status="Good"
      printf '> Bluetooth is already on and working.\n' >>"${report_file}"
    else
      echo "Turning Bluetooth on…"
      blueutil -p 1
      sleep 2
      bluetooth_status="$(blueutil -p)"
      if [[ "${bluetooth_status}" -eq 1 ]]; then
        echo "Bluetooth works after enabling."
        bt_status="Good"
        printf '> Bluetooth had to be turned on and is working.\n' >>"${report_file}"
      else
        echo "Bluetooth seems to be broken."
        bt_status="Broken❗"
        printf '> Bluetooth seems to be broken. Please test manually.\n' >>"${report_file}"
      fi
    fi
  else
    bt_status="Unknown❗"
    printf '> Could not validate Bluetooth (blueutil unavailable). Test manually.\n' >>"${report_file}"
  fi

  update_list_item 6 "success" "${bt_status}"

  printf '\n\n' >>"${report_file}"
}

usb_ports_step() {
  update_list_item 7 "progress" "Checking USB‑C ports…"
  log_section "USB Ports"

  local usb_devices usb_update usb_status

  usb_devices="$(system_profiler SPUSBDataType || true)"
  sleep 3

  if [[ -z "${usb_devices}" ]]; then
    usb_update="Broken ❗"
    usb_status="failed"
  else
    usb_update="Good"
    usb_status="success"
  fi

  printf '> Condition: %s\n\n\n' "${usb_update}" >>"${report_file}"

  update_list_item 7 "${usb_status}" "${usb_update}"
}

speaker_condition_step() {
  update_list_item 8 "progress" "Running speaker test…"
  log_section "Speakers"

  afplay /System/Library/Sounds/Ping.aiff >/dev/null 2>&1 &
  sleep 1

  local speaker_status
  if pgrep -x "coreaudiod" >/dev/null 2>&1; then
    speaker_status="Good"
  else
    speaker_status="Broken❗"
  fi

  printf '> Condition: %s\n\n\n' "${speaker_status}" >>"${report_file}"

  update_list_item 8 "success" "${speaker_status}"
}

mic_condition_step() {
  update_list_item 9 "progress" "Running microphone tests…"
  log_section "Microphone"

  rec -q /dev/null trim 0 1 >/dev/null 2>&1 || true
  sleep 2

  local mic_status
  if pgrep -x "coreaudiod" >/dev/null 2>&1; then
    mic_status="Good"
  else
    mic_status="Broken❗"
  fi

  printf '> Condition: %s\n\n\n' "${mic_status}" >>"${report_file}"

  update_list_item 9 "success" "${mic_status}"
}

icloud_status_step() {
  update_list_item 10 "progress" "Checking iCloud status…"
  log_section "iCloud Status"

  local currentUser iCloudLoggedInCheck

  currentUser="$(current_console_user)"
  iCloudLoggedInCheck="$(defaults read "/Users/${currentUser}/Library/Preferences/MobileMeAccounts" Accounts 2>/dev/null || true)"

  local iCloudLoggedIn status_icon icloud_report

  if [[ "${iCloudLoggedInCheck}" == *"AccountID"* ]]; then
    iCloudLoggedIn="iCloud – YES ❗"
    status_icon="failed"
    icloud_report="iCloud – YES ❗ Please remove the device from the iCloud account."
    all_good_icloud="no"
  else
    iCloudLoggedIn="iCloud – NO"
    status_icon="success"
    icloud_report="iCloud – NO"
    all_good_icloud="yes"
  fi

  echo "iCloud: ${iCloudLoggedIn}"
  printf '> %s\n\n\n' "${icloud_report}" >>"${report_file}"

  update_list_item 10 "${status_icon}" "${iCloudLoggedIn}"
}

final_report_step() {
  update_list_item 11 "progress" "Generating report…"

  echo "Cleaning up SSD test files…"
  sleep 1
  [[ -n "${tempfile}" ]] && safe_rm "${tempfile}"
  safe_rm "/tmp/ssd_test.bin"
  sleep 2

  update_list_item 11 "success" "Complete"

  sleep 1

  echo "Closing progress dialog and removing JSON file…"
  killall Dialog 2>/dev/null || true
  safe_rm "${JSON_FILE}"

  export_report_dialog
}

#######################################
# Erase‑readiness and Jamf integration
#######################################

all_good_step() {
  erase_all_settings_dialog() {
    local dTitle dMessage

    dTitle="Working…"
    dMessage=$(
      cat <<EOF
We are excluding you from the lock policy.

Shortly you will see Settings > General open. Please scroll to the bottom and click
**Transfer or Reset** followed by **Erase all contents and settings**.

Once you open that window, simply authenticate and let macOS do the rest!
EOF
    )

    "${DIALOG_PATH}" \
      --title "${dTitle}" \
      --message "${dMessage}" \
      --messagefont "name=Arial-MT,size=13" \
      --icon "${dialog_icon_dir}" \
      --iconsize 120 \
      --button1text "OK" \
      --background "${dialog_background}" \
      --moveable \
      --progress
  }

  add_to_jamf() {
    sudo /usr/local/bin/jamf recon -room "hardware_pass"
    open "x-apple.systempreferences:com.apple.SystemPreferences?General"
  }

  if [[ "${all_good_icloud}" == "yes" ]]; then
    echo "iCloud is signed out; device is eligible for erase prompt."

    local dTitle dMessage dialogSelection returncode

    dTitle="Erase all data and settings?"
    dMessage=$(
      cat <<EOF
Everything passed in the test.

Would you like to **Erase all contents and settings** to set this Mac up for the next user?

This dialog will auto‑dismiss in 30 seconds and no action will be taken if you do nothing.
EOF
    )

    dialogSelection="$(
      "${DIALOG_PATH}" \
        --title "${dTitle}" \
        --message "${dMessage}" \
        --messagefont "name=Arial-MT,size=13" \
        --icon "${dialog_icon_dir}" \
        --iconsize 120 \
        --background "${dialog_background}" \
        --moveable \
        --button1text "YES" \
        --button2text "NO" \
        --timer 30
    )"

    returncode=$?

    case "${returncode}" in
      0)
        echo "User chose YES to erase."
        erase_all_settings_dialog &
        add_to_jamf
        killall Dialog 2>/dev/null || true
        exit 0
        ;;
      2)
        echo "User chose NO to erase."
        exit 0
        ;;
      *)
        echo "Erase prompt dialog error: exit code ${returncode}"
        exit 0
        ;;
    esac
  else
    echo "iCloud is still signed in; not offering erase flow."
  fi
}

#######################################
# Main
#######################################

main() {
  safe_rm "${report_file}"

  check_password
  power_check_launch

  init_dialog_json
  launch_progress_dialog

  initialize_step
  power_check_step
  battery_condition_step
  cpu_condition_step
  ssd_condition_step
  network_condition_step
  bt_condition_step
  usb_ports_step
  speaker_condition_step
  mic_condition_step
  icloud_status_step
  final_report_step

  all_good_step
}

main "$@"



----------OG
#!/bin/bash

## Designed by Travis Green - Jan 2nd 2025
# Uses swift dialog for all dialogs and user input
# 1. Asks for a specific built in password - uses parameters when run through Jamf
# 2. Asks for power plugin to test charging - user can skip and dialog can time out and charging won't be tested
# 3. Progress dashboard loads
# 4. Tests charging + Battery condition + cycle count
# 5. Tests read/write speeds for CPU
# 6. Downloads a small file and copy/pastes it to test SSD read/write speeds
# 7. Pings 8.8.8.8 and uses a github repository to test network speeds (up and down)
# 8. Checks for BT radio using github repository - turns it on if off, to ensure it works
# 9. Checks for all USB ports and makes sure they are able to read content
# 10. Plays a small sound to test speakers
# 11. Tests microphone
# 12. Checks for iCloud login since this needs to be removed for new user/retirnment
# 14. Puts logs into a temp file which gets converted into a "report file.txt" for troubleshooting
# 15. If iCloud is not signed in (this is the only requirnment) - it asks to erase - if yes: sudo jamf recon -room "hardware_pass" is run
# ---- hardware_pass adds device to a smart group that is excluded in the "block erase and restore" settings, enabling the feature
# ---- once this happens, Systems Settings > General loads for convenience to erase.

DIALOG_PATH="/usr/local/bin/dialog"
dialog_background="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialog_icon_dir="/Library/Application Support/SideIT/ATTIcon.png"
report_file="/tmp/report.txt"
#delete report file just in case
sudo rm -rf $report_file
power_timer=120
side_it_password="$4"

check_password () {
	
passCheck=" "
passTitle="Attention: Side IT Password Required"

until [ "$passCheck" == "PASSED" ]; do
	
dTitle="Side IT Password Required"
dMessage="Due to high risk, this policy is password protected by Side IT Helpdesk.\n\n\
Only run this under Side IT supervision.\n\n\
	
Please enter the policy password. If you do not have it, please contact helpdesk@side.com"
dButton1="Start"
dButton2="Cancel"
dTimer=30 #turn into 60 for one minute
dPostponeTitle="Postpone until"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."


		pass_check=$(${DIALOG_PATH} \
		    --title "$dTitle" \
			--titlefont "$dialogTitleFont" \
		    --message "$dMessage" \
			--messagefont "name=Arial-MT,size=18" \
		    --icon "$dialog_icon_dir" \
			--iconsize 120 \
		    --button1text "$dButton1" \
			--button2text "$dButton2" \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--textfield "Password",required,secure \
			--big \
			--background "$dialog_background"
		)
			
			
			
			#Button pressed Stuff
			returncode=$?
			
			echo "Pass Check: ${pass_check}"


			case ${returncode} in
			    0)  echo "Pressed Button 1: Start"
				
				if [ "$pass_check" = "Password : ${side_it_password}" ]; then
			    	echo "Password Check: PASSED"
					passCheck="PASSED"
			    	# DO THE REST OF YOUR ACTIONS...
					

				else
			    	# Prompt for User Password
			    	echo "Password Check: WRONG PASSWORD"
			    	#wrongUserPassword
					passCheck="FAILED"
			
				fi
	
			        ;;

			    2)  echo "Pressed Button 2: cancel"
			    exit 0
			 
			        ;;
		
			    *)  echo "Error: No Button Pressed. exit code ${returncode}"
				exit 0

			        ;;
			esac

	

	

done
killall Dialog

}

check_password








## Check power

power_check_launch () {


# Dialog for power check with timer
	power_check_dialog () {
		
dMessage="In order to complete the diagnostic test, the device must be connected to a power source.\n
Please ensure the computer is connected to a power source to proceed with the test.\n
If a power source is not connected within the next two minutes, this alert will automatically dismiss, and the charge test will not be performed."

			timer=$power_timer  # 2 minutes = 120 seconds
			web="https://i.pinimg.com/originals/59/df/95/59df95ecfb490ed3bab39a283ae7d8fa.gif"

	        # Show the dialog with timer and wait for the dialog to close
	        $DIALOG_PATH --title "Initializing. Power Source Connection Required" \
	                     --titlefont "name=Arial-MT,colour=#CE87C1,size=30" \
	                     --message "$dMessage" \
	                     --messagefont "name=Arial-MT,size=15" \
	                     --icon "$dialog_icon_dir" \
	                     --iconsize 250 \
	                     --webcontent "$web" \
	                     --background "$dialog_background" \
	                     --timer "$timer" \
	                     --moveable \
						 --ontop
	    }

	    # Function to check if the device is plugged into power
	    check_power_source() {
	        pmset -g batt | grep "AC Power" &> /dev/null
	        return $?
	    }

		launch_power_dialog () {
		    # Start the power check dialog in the background
		    power_check_dialog &

		    local timer=$power_timer  # Set the timer for 10 seconds
		    local start_time=$(date +%s)

		    while true; do
		        # Check if power is connected
		        if check_power_source; then
		            echo "Power source connected. Dismissing dialog."
		            killall Dialog
		            power_status="Good"
					power_status_report="Good - Charge when plugged in."
					power_mark="success"
		            break
		        fi

		        # Check if the timer has expired
		        local current_time=$(date +%s)
		        if (( current_time - start_time >= timer )); then
		            echo "Timer expired. Dismissing dialog."
		            killall Dialog
		            power_status="Unknown❗"
					power_status_report="Unknown❗- Charger not plugged in or damaged. Please verify manually."
					power_mark="failed"
		            break
		        fi

		        echo "Power not connected, waiting... ${current_time} seconds..."
		        sleep 1
		    done
		}


		# Initial check for power source
		if check_power_source; then
		    echo "The laptop is running on AC power."
		    power_status="Good"
			power_status_report="Good - Device was already charging"
			power_mark="success"
		else
		    echo "The laptop is running on battery power."
		    launch_power_dialog  # Start the dialog process if power is not plugged in
		fi
	

}

power_check_launch







# Path to the temporary JSON file for the dialog
#JSON_FILE=$(mktemp)

JSON_FILE="/tmp/diagnostic_test.json"

# Initialize JSON content with a list
cat <<EOF > "$JSON_FILE"
{
  "title": "Side Inc Hardware Diagnostic Test",
  "message": "Diagostic Test Running. This won't take long.",
  "listitem": [
    {"title": "Initializing", "status": "pending", "statustext": "Pending"},
	{"title": "Charger", "status": "pending", "statustext": "Pending"},
	{"title": "Battery", "status": "pending", "statustext": "Pending"},
	{"title": "CPU", "status": "pending", "statustext": "Pending"},
    {"title": "SSD", "status": "pending", "statustext": "Pending"},
    {"title": "Network", "status": "pending", "statustext": "Pending"},
	{"title": "Bluetooth", "status": "pending", "statustext": "Pending"},
	{"title": "USB Ports", "status": "pending", "statustext": "Pending"},
	{"title": "Speakers", "status": "pending", "statustext": "Pending"},
	{"title": "Microphone", "status": "pending", "statustext": "Pending"},
    {"title": "iCloud Status", "status": "pending", "statustext": "Pending"},
    {"title": "Building Report", "status": "pending", "statustext": "Pending"}
  ]
}
EOF


# Launch Swift Dialog in the background
$DIALOG_PATH --jsonfile "$JSON_FILE" --infobox --big  --ontop --moveable --progress --background "$dialog_background" --icon "$dialog_icon_dir" --button1text "Cancel" &
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





export_report_dialog () {

echo "export report dialog launch"
	
print_report=$(cat "$report_file")
	
dTitle="Side Inc Diagnostic Test"
dMessage="Click **Export** to get a text copy of the report.\n\nThis dialog will auto dismiss in 5 minutes\n\n
**For extra caution, please test anything concerning manually.\n\n**
$print_report"
timer=300
								 
								 
								 
							 	dialogSelection=$(${DIALOG_PATH} \
							 	    --title "$dTitle" \
							 	    --message "$dMessage" \
									--messagefont "name=Arial-MT,size=13" \
							 	    --icon "$dialog_icon_dir" \
							 		--iconsize 120 \
							 	    --button1text "Exit" \
							 	    --button2text "Export" \
							 		--background "$dialog_background" \
							 		--moveable \
							         --timer "$timer"
	
							 	)		



	#Button pressed Stuff
	returncode=$?


	case ${returncode} in
	    0)  echo "Pressed Button 1: exit"
		echo "Exiting the script."
	
	        ;;

	    2)  echo "Pressed Button 2: export"
	    echo "Exporting the report..."
	    date=$(date "+%Y-%m-%d_%H-%M-%S")
		serial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
	    sudo cp $report_file "$HOME/Desktop/${date} - ${serial}.txt"
	

	        ;;
		
	    *)  echo "Error: No Button Pressed. exit code ${returncode}"
		exit 0

	        ;;
	esac
	





sudo rm -rf $report_file
killall Dialog

	

}

initialize () {
  update_list_item 0 "progress" "*Initializing...*"
  echo "Downloading file for SSD test"
  
  url="https://api.textmate.org/downloads/release?os=10.12"
  pkgfile='ssd_test.pkg'
  dir='/tmp/'$pkgfile
  #Downloading PKG
  echo "Downloading..."
  /usr/bin/curl -L -o $dir ${url} 
  
  
  
  #check for power
  sleep 3
  
  update_list_item 0 "success" "Done"
}

power_check () {
    update_list_item 1 "progress" "Getting Charging Information"
	echo "**Power:**" >> "$report_file"
	echo "> Condition: ${power_status_report}" >> "$report_file"
	sleep 1
	
	echo "" >> "$report_file"
	echo "" >> "$report_file"
  
    update_list_item 1 "$power_mark" "$power_status"
}


battery_condition () {
  update_list_item 2 "progress" "Running Battery Tests..."
  echo "**Battery:**" >> "$report_file"
 
  
  echo "Getting battery cycle count"
  battery_cycle_count=$(system_profiler SPPowerDataType | grep "Cycle Count:" | sed 's/.*Cycle Count: //')
  
  echo "> Cycle Count: $battery_cycle_count \n" >> "$report_file"
  
  echo "Getting battery condition"
  battery_condition=$(system_profiler SPPowerDataType | grep "Condition:" | sed 's/.*Condition: //')
  echo "> Condition: $battery_condition" >> "$report_file"
  
  batteryResult="${battery_condition} * Cycle Count ${battery_cycle_count}"
  echo "Battery Results: $batteryResult"

  
  update_list_item 2 "success" "$batteryResult"
  
  echo "" >> "$report_file"
  echo "" >> "$report_file"

}

cpu_condition () {

    update_list_item 3 "progress" "Running CPU Tests"
	echo "**CPU:**" >> "$report_file"

    # Temporary file for testing
    cpu_temp_file=$dir

    # Block size and count for testing
    block_size=1M
    block_count=1024

    # Function to convert bytes/sec to GB/sec and round to 2 decimal places
    convert_to_gb_per_sec() {
        # Remove non-numeric characters from input
        clean_value=$(echo "$1" | tr -cd '[:digit:].')
  
        # Convert to GB/sec and round to 2 decimal places using printf
        printf "%.2f\n" $(echo "$clean_value / 1073741824" | bc -l)
    }

    echo "Testing write speed..."
    # Measure write speed using `dd` and display raw output for debugging
    write_output=$(dd if=/dev/zero of=$cpu_temp_file bs=$block_size count=$block_count oflag=direct 2>&1)
    echo "Raw write output: $write_output"  # Debugging line

    # Extract transfer rate in bytes/sec using awk
    cpu_write_speed=$(echo "$write_output" | awk '/bytes transferred/ {print $(NF-1)}')

    # Convert to GB/s
    cpu_write_speed_gb=$(convert_to_gb_per_sec "$cpu_write_speed")

    # Output write speed, rounded to 2 decimal places
    echo "Write Speed: $cpu_write_speed_gb GB/s"

    echo "Testing read speed..."
    # Measure read speed using `dd` and display raw output for debugging
    read_output=$(dd if=$cpu_temp_file of=/dev/null bs=$block_size count=$block_count iflag=direct 2>&1)
    echo "Raw read output: $read_output"  # Debugging line

    # Extract transfer rate in bytes/sec using awk
    cpu_read_speed=$(echo "$read_output" | awk '/bytes transferred/ {print $(NF-1)}')

    # Convert to GB/s
    cpu_read_speed_gb=$(convert_to_gb_per_sec "$cpu_read_speed")

    # Output read speed, rounded to 2 decimal places
    echo "Read Speed: $cpu_read_speed_gb GB/s"
	
	echo "> Read Speed: $cpu_read_speed_gb GB/s \n" >> "$report_file"
	echo "> Write Speed: $cpu_write_speed_gb GB/s" >> "$report_file"

    update_list_item 3 "success" "Read $cpu_read_speed_gb GB/s * Write $cpu_write_speed_gb GB/s"
	
    echo "" >> "$report_file"
    echo "" >> "$report_file"
}

ssd_condition () {
  update_list_item 4 "progress" "Running SSD Tests..."
  
  echo "**SSD:**" >> "$report_file"

  tempfile="/tmp/ssd_test.pkg"

  # Function to convert bytes to MB
  bytes_to_mb() {
    echo "scale=2; $1 / 1048576" | bc
  }

  # Function to convert MB to GB
  mb_to_gb() {
    echo "scale=2; $1 / 1024" | bc
  }

  # Test write speed
  echo "Testing write speed..."
  write_output=$(dd if=/dev/zero of=$tempfile bs=1G count=1 oflag=direct 2>&1)
  write_bytes=$(echo "$write_output" | awk '/bytes transferred/ {gsub(/[()]/, "", $(NF-1)); print $(NF-1)}')
  write_speed_mb=$(bytes_to_mb $write_bytes)
  write_speed_gb=$(mb_to_gb $write_speed_mb)
  
  echo "> Write Speed: $write_speed_gb GB/second \n" >> "$report_file"

  # Sync to ensure data is written to disk
  sync

  # Test read speed
  echo "Testing read speed..."
  read_output=$(dd if=$tempfile of=/dev/null bs=1G count=1 iflag=direct 2>&1)
  read_bytes=$(echo "$read_output" | awk '/bytes transferred/ {gsub(/[()]/, "", $(NF-1)); print $(NF-1)}')
  read_speed_mb=$(bytes_to_mb $read_bytes)
  read_speed_gb=$(mb_to_gb $read_speed_mb)
  
  echo "> Read Speed: $read_speed_gb GB/second" >> "$report_file"

  ssd_results="Read ${read_speed_gb}GBs * Write ${write_speed_gb}GBs"
  echo "SSD Test Results: $ssd_results"
  
  

  # Properly pass the string to the function
  update_list_item 4 "success" "$ssd_results"
  
  echo "" >> "$report_file"
  echo "" >> "$report_file"
}

network_condition () {
  update_list_item 5 "progress" "Running Network Tests..."
  
 
  echo "**Network:**" >> "$report_file"
  

  if ping -c 4 8.8.8.8 > /dev/null 2>&1; then
      wifi_status="Good"
	  
	  sleep 2
    
      # Fetch and run speedtest to measure network performance
      speed_test=$(curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 2>/dev/null)
    
      # Extract Download and Upload speeds
      download_speed=$(echo "$speed_test" | grep 'Download' | awk '{print $2, $3}')
      upload_speed=$(echo "$speed_test" | grep 'Upload' | awk '{print $2, $3}')
    
      # Handle cases where speedtest might fail
      if [[ -z "$download_speed" || -z "$upload_speed" ]]; then
          download_speed="Download unavailable❗"
          upload_speed="Upload unavailable❗"
      fi
  else
      wifi_status="Bad❗"
      download_speed="No connection❗"
      upload_speed="NA❗"
  fi


  # Output the final status
  show_result="DN:$download_speed * UP:$upload_speed"
  echo "echoing result: $show_result"
  
  echo "> Download Speed: $download_speed \n" >> "$report_file"
  echo "> Upload Speed: $upload_speed" >> "$report_file"
  
  update_list_item 5 "success" "$show_result"
  
  
  echo "" >> "$report_file"
  echo "" >> "$report_file"

}

bt_condition () {

    update_list_item 6 "progress" "Running BT Tests"
	
	echo "**Bluetooth**" >> "$report_file"
	
	# Install Homebrew if it's not installed
	if ! command -v brew &> /dev/null; then
	  echo "Homebrew is not installed. Installing Homebrew..."
	  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	  if [ $? -ne 0 ]; then
	    echo "Error: Homebrew installation failed."
		bt_status="Homebrew installation failed. Please test Bluetooth manually."
		echo "> ${bt_status}" >> "$report_file"
	    #exit 1
	  fi
	  echo "Homebrew installed successfully."
  
	  # Add Homebrew to PATH (if needed)
	  export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
	fi

	# Install blueutil if it's not already installed
	if ! command -v blueutil &> /dev/null; then
	  echo "Installing blueutil..."
	  brew install blueutil
	  if [ $? -ne 0 ]; then
	    echo "Error: Failed to install blueutil."
		bt_status="Blueutil installation failed. Please test Bluetooth manually."
		echo "> ${bt_status}" >> "$report_file"
	    #exit 1
	  fi
	fi

	# Check Bluetooth status
	bluetooth_status=$(blueutil -p)
	if [ "$bluetooth_status" -eq 1 ]; then
	  echo "Bluetooth is already on."
    echo "Bluetooth works."
	bt_status="Good"
	echo "> Bluetooth is already on and working" >> "$report_file"
	else
	  # Try turning Bluetooth on
	  echo "Turning Bluetooth on..."
	  blueutil -p 1
	  sleep 2

	  # Check status again after attempting to turn it on
	  bluetooth_status=$(blueutil -p)
	  if [ "$bluetooth_status" -eq 1 ]; then
	    echo "Bluetooth works."
		bt_status="Good"
		echo "> Bluetooth had to be turned on, and is working" >> "$report_file"
	  else
	    echo "Bluetooth seems to be broken."
		bt_status="Broken❗"
		echo "> Bluetooth seems to be broken. Please test it manually" >> "$report_file"
	  fi
	fi
  
    update_list_item 6 "success" "$bt_status"
	
    echo "" >> "$report_file"
    echo "" >> "$report_file"

}

usb_ports () {
	
	update_list_item 7 "progress" "Checking USB-C Ports"
	

	echo "**USB Ports:**" >> "$report_file"
	
	
	# Check USB devices on macOS using system_profiler
	usb_devices=$(system_profiler SPUSBDataType)
	
	sleep 3

	if [[ -z "$usb_devices" ]]; then
	    echo "Broken"
		usb_update="Broken ❗"
		usb_status="failed"
		
	else
	    echo "Good"
		usb_update="Good"
		usb_status="success"
	fi
	
	echo "> Condition: $usb_update" >> "$report_file"
	
	sleep 3
	
	update_list_item 7 "${usb_status}" "${usb_update}"
	
    echo "" >> "$report_file"
    echo "" >> "$report_file"

}

speaker_condition () {
    update_list_item 8 "progress" "Running Speaker Test"
	echo "**Speakers:**" >> "$report_file"
	
	afplay /System/Library/Sounds/Ping.aiff &
	sleep 1 # Wait for the sound to play
	if pgrep -x "coreaudiod" > /dev/null; then
	  echo "Speakers work"
	  speaker_status="Good"
	else
	  echo "Speakers broken"
	  speaker_status="Broken❗"
	fi
	
	echo "> Condition: ${speaker_status}" >> "$report_file"
  
    update_list_item 8 "success" "$speaker_status"
	
    echo "" >> "$report_file"
    echo "" >> "$report_file"
}

mic_condition () {
    update_list_item 9 "progress" "Running Microphone Tests"
	echo "**Microphone:**" >> "$report_file"
	
	# Record 1 second of audio from the default microphone
	rec -q /dev/null trim 0 1 > /dev/null 2>&1 &
	sleep 2 # Wait for recording to finish

	# Check if coreaudiod is still running
	if pgrep -x "coreaudiod" > /dev/null; then
	  echo "Microphone works"
	  mic_status="Good"
	else
	  echo "Microphone broken"
	  mic_status="Broken ❗"
	fi
	
	echo "> Condition: ${mic_status}" >> "$report_file"
	
    update_list_item 9 "success" "$mic_status"
	
	echo "" >> "$report_file"
	echo "" >> "$report_file"
	
}

icloud_status () {
  update_list_item 10 "progress" "Checking iCloud Status..."

  echo "**iCloud Status:**" >> "$report_file"
  
  
  currentUser=$(stat -f%Su /dev/console)

  iCloudLoggedInCheck=$(defaults read /Users/$currentUser/Library/Preferences/MobileMeAccounts Accounts)

  if [[ "$iCloudLoggedInCheck" = *"AccountID"* ]]; then
  iCloudLoggedIn="iCloud - YES ❗"
  status_icon="failed"
  icloud_report="iCloud - YES ❗Please remove the device from the iCloud account."
  all_good_icloud="no"
  
  else
  iCloudLoggedIn="iCloud - NO"
  status_icon="success"
  icloud_report="iCloud - NO"
  all_good_icloud="yes"
  fi

  echo "iCloud: $iCloudLoggedIn"
  echo "> $icloud_report" >> "$report_file"
  
  
  update_list_item 10 "$status_icon" "$iCloudLoggedIn"
  
  echo "" >> "$report_file"
  echo "" >> "$report_file"
}

final_report () {
	
  update_list_item 11 "progress" "Generating Report..."
  echo "Cleaning up SSD test files"
  sleep 1
  sudo rm -rf $tempfile
  sleep 2
  update_list_item 11 "success" "Complete"
  
  sleep 1
  
  echo "Killing original dialog"
  killall Dialog
  echo "Cleaning JSON file"
  sudo rm -rf "$JSON_FILE"
  echo "launch report dialog"
  export_report_dialog
}

all_good () {

	erase_all_settings_dialog () {
dTitle="Working..."
dMessage="We are excluding you from the lock policy.\n\n
Shortly you will see Settings > General open. Please scroll to the bottom and click\n
**Transfer or Reset** followed by **Erase all contents and settings**.\n\n
Once you open that window, simply authenticate and let macOS do the rest!"
timer=30

								 
								 
								 
											 	dialogSelection=$(${DIALOG_PATH} \
											 	    --title "$dTitle" \
											 	    --message "$dMessage" \
													--messagefont "name=Arial-MT,size=13" \
											 	    --icon "$dialog_icon_dir" \
											 		--iconsize 120 \
											 	    --button1text "Ok" \
											 		--background "$dialog_background" \
											 		--moveable \
													--progress
				
	
											 	)
	
	}
	
	add_to_jamf () {
	
		sudo jamf recon -room "hardware_pass"
		open "x-apple.systempreferences:com.apple.SystemPreferences?General"
	}


	if [ "$all_good_icloud" = "yes" ]; then
	    echo "All good with iCloud!"
	    
		
dTitle="Erase all data and settings?"
dMessage="Everything passed in the test.\n\n
Would you like to Erase all contents and settings to set it up for the next user?\n\n\
This dialog will auto dismiss in 30 seconds and no action will be taken."
timer=30

								 
								 
								 
									 	dialogSelection=$(${DIALOG_PATH} \
									 	    --title "$dTitle" \
									 	    --message "$dMessage" \
											--messagefont "name=Arial-MT,size=13" \
									 	    --icon "$dialog_icon_dir" \
									 		--iconsize 120 \
									 		--background "$dialog_background" \
									 		--moveable \
											--button1text "YES" \
											--button2text "NO"
	
									 	)		



			#Button pressed Stuff
			returncode=$?


			case ${returncode} in
			    0)  echo "Pressed Button 1: Yes"
				#add to jamf group & show dialog with progrssion
	erase_all_settings_dialog & add_to_jamf
	killall Dialog
	exit 0
			        ;;

			    2)  echo "Pressed Button 2: NO"
			    echo "No"
				exit 0
	

			        ;;
		
			    *)  echo "Error: No Button Pressed. exit code ${returncode}"
				exit 0

			        ;;
			esac
	
		
		
		
	else
	    echo "iCloud status is not good."
	    # Add alternative commands here
	fi


}

# Execute the installation functions
initialize #update_list_item 0

#Power - if plugged in, unplug, if unplugged, plug in
power_check #update_list_item 1

#battery_condition
battery_condition #update_list_item 2

#CPU
cpu_condition #update_list_item 3

#SSD #rename to ssd_condition
ssd_condition #update_list_item 4

#Network #rename to network_condition
network_condition #update_list_item 5

#Bluetooth
bt_condition #update_list_item 6

#USB Ports
usb_ports #update_list_item 7

#Speakers
speaker_condition #update_list_item 8

#Mic
mic_condition #update_list_itel 9

#iCloud #rename to icloud_status
icloud_status #update_list_item 10

#report #rename to final_report
final_report #update_list_item 11

#if all good - allow erase
all_good
