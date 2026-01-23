
#!/usr/bin/env bash
#
# Hackathon 2024 – Side Live Operations Board
#
# Description:
#   Rotating swiftDialog dashboard showing:
#     - Live driving times from the Side SF office
#     - BART status and Civic Center departures
#     - Caltrain service alerts
#     - Core SaaS service and website statuses
#
# Requirements:
#   - macOS with: swiftDialog, Shortcuts, Apple Maps
#   - CLI tools: curl, jq, osascript, pbcopy/pbpaste
#   - APIs: BART, 511.org (Caltrain), Gemini, external status pages
#
# Dialog sequence:
#   1. Loading dialog + initial driving times
#   2. Live Traffic (driving ETA + map)
#   3. BART (alerts + Civic Center schedule + webview)
#   4. Caltrain (alerts via 511 + Gemini cleanup + webview)
#   5. Service Status (SaaS + website uptime)
#
# Notes:
#   - Slides rotate in an endless loop.
#   - BART / Caltrain API calls are rate‑limited via countdown counters.
#   - Driving times are refreshed between slides to avoid API/shortcut spam.

set -euo pipefail

#######################################
# Global configuration
#######################################

set_master_variables() {
  # API keys (configure via environment or here)
  caltrain_api_key="${CALTRAIN_API_KEY:-your-511-org-api-key}"
  gemini_key="${GEMINI_KEY:-your-gemini-cli-api-key}"
  BART_API_KEY="${BART_API_KEY:-your-bart-api-key}"

  # Rate‑limit state
  caltrain_api_countdown=4
  caltrain_api_pull_time="$(date +"%m-%d-%Y %H:%M:%S")"

  bart_api_countdown=4
  bart_api_pull_time="$(date +"%m-%d-%Y %H:%M:%S")"

  # swiftDialog paths / versions
  updatedDialogVersion="2.5.3"
  dialog_bin="/usr/local/bin/dialog"
  dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.3/dialog-2.5.3-4785.pkg"
  dialogDir="/usr/local/"
  swiftDialogPKG="swiftDialog.pkg"
  dialogAppDir="/Library/Application Support/Dialog/Dialog.app"

  # Wallpaper / branding
  wallpaperDir="/Library/Application Support/wallpaper/"
  wallpaperImg="desktopwallpaper.jpg"
  wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"

  dialogTimer=15
  dialogIconDir="/Library/Application Support/SideIT/finishing.png"
  dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
  dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
  dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
  dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
}

#######################################
# Dialog installation / validation
#######################################

install_dialog() {
  # Ensure wallpaper is present
  if [[ -f "${wallpaperDir}${wallpaperImg}" ]]; then
    echo "Wallpaper present, skipping install."
  else
    echo "Installing wallpaper package..."
    sudo /usr/sbin/installer -pkg "${wallpaperPKGDir}" -target /
  fi

  # Ensure swiftDialog is present and up to date
  if [[ -x "${dialog_bin}" ]]; then
    echo "swiftDialog found, checking version..."
    dialogVersion="$(defaults read "${dialogAppDir}/Contents/Info" CFBundleShortVersionString)"
    echo "swiftDialog version: ${dialogVersion}"

    if [[ "${dialogVersion}" != "${updatedDialogVersion}" ]]; then
      echo "swiftDialog out of date, updating..."
      sudo /usr/bin/curl -L "${dialog_download_url}" -o "${dialogDir}${swiftDialogPKG}"
      sudo /usr/sbin/installer -pkg "${dialogDir}${swiftDialogPKG}" -target /
      sleep 5
      sudo rm -f "${dialogDir}${swiftDialogPKG}"
    else
      echo "swiftDialog is up to date, skipping update."
    fi
  else
    echo "swiftDialog not found, installing..."
    sudo /usr/bin/curl -L "${dialog_download_url}" -o "${dialogDir}${swiftDialogPKG}"
    sudo /usr/sbin/installer -pkg "${dialogDir}${swiftDialogPKG}" -target /
    sleep 5
    sudo rm -f "${dialogDir}${swiftDialogPKG}"
  fi
}

#######################################
# Services slide – dialog + data
#######################################

services_dialog() {
  local dTitle dMessage dButton1 timer dIconDir dBackDir dInfoBox returncode

  dTitle="Service Statuses"
  dMessage=$(
    cat <<EOF
Website statuses are pulled from isitdownrightnow.com (main site only).
Service statuses are pulled from each provider's status page.

Google WWW:  ${status_google}   |   Service:  ${google_status}

Okta WWW:    ${status_okta}     |   Service:  ${okta_status}

Slack WWW:   ${status_slack}    |   Service:  ${slack_status}

Atlassian WWW: ${status_atlassian} | Service: ${atlassian_status}

Zoom WWW:    ${status_zoom}     |   Service:  ${zoom_status}

Side WWW:    ${status_side}
EOF
  )

  dButton1="Quit"
  timer="${dialogTimer}"
  dIconDir="${dialogIconDir}"
  dBackDir="${dialogBackGroundDir}"
  dInfoBox="__Welcome to Side!__\n\n__580 4th St, San Francisco, CA__\n\n(415) 525-4913\n\n__Need Help?__\n[helpdesk@side.com](${dialogHDURL})"

  get_driving_traffic_data &

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --alignment center \
    --messagefont "name=Arial-MT,size=20" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --height 100% \
    --width 100% \
    --background "${dBackDir}" \
    --infobox "${dInfoBox}" \
    --timer "${timer}" \
    --webcontent "https://i.gifer.com/PYHc.gif"

  returncode=$?

  case "${returncode}" in
    0)
      echo "Service dialog: Quit requested."
      pkill -f "[D]ialog" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "Service dialog: Continuing to next slide."
      ;;
  esac
}

get_services_data() {
  get_service_statuses() {
    google_status_pull() {
      local status_page
      status_page="$(curl -s https://www.google.com/appsstatus/ || true)"

      if echo "${status_page}" | grep -q 'class="status yellow"' ||
         echo "${status_page}" | grep -q 'class="status red"'; then
        google_status="Experiencing issues"
      else
        google_status="✅"
      fi
    }

    okta_status_pull() {
      local status_json
      status_json="$(curl -s https://status.okta.com/api/v2/status.json || true)"

      if echo "${status_json}" | grep -q '"status":"active"'; then
        okta_status="Experiencing issues"
      elif echo "${status_json}" | grep -q '"status":"degraded_performance"'; then
        okta_status="Experiencing issues"
      else
        okta_status="✅"
      fi
    }

    slack_status_pull() {
      local page
      page="$(curl -s https://slack-status.com/ || true)"

      if echo "${page}" | grep -q "Some users may be having trouble sending messages"; then
        slack_status="Experiencing trouble sending messages"
      elif echo "${page}" | grep -q "Some users may be having trouble sending files"; then
        slack_status="Experiencing trouble sending files"
      elif echo "${page}" | grep -q "Some users may be having trouble loading threads"; then
        slack_status="Experiencing trouble loading threads"
      else
        slack_status="✅"
      fi
    }

    zoom_status_pull() {
      local status_json incidents
      status_json="$(curl -s https://api.zoom.us/v2/metrics/status || true)"
      incidents="$(echo "${status_json}" | jq -r '.incidents | length' 2>/dev/null || echo 0)"

      if [[ "${incidents}" -gt 0 ]]; then
        zoom_status="Experiencing ${incidents}"
      else
        zoom_status="✅"
      fi
    }

    atlassian_status_pull() {
      local status_json incidents
      status_json="$(curl -s https://api.status.atlassian.com/1.0/status || true)"
      incidents="$(echo "${status_json}" | jq -r '.incidents | length' 2>/dev/null || echo 0)"

      if [[ "${incidents}" -gt 0 ]]; then
        atlassian_status="Experiencing ${incidents}"
      else
        atlassian_status="✅"
      fi
    }

    google_status_pull
    okta_status_pull
    slack_status_pull
    zoom_status_pull
    atlassian_status_pull
  }

  get_site_statuses() {
    check_status() {
      local url="$1"
      local response

      response="$(curl -s "${url}" || true)"

      if echo "${response}" | grep -q "is UP"; then
        echo "✅"
      elif echo "${response}" | grep -q "is DOWN"; then
        echo "DOWN"
      else
        echo "Unknown"
      fi
    }

    status_google="$(check_status "https://www.isitdownrightnow.com/google.com.html")"
    status_okta="$(check_status "https://www.isitdownrightnow.com/okta.com.html")"
    status_slack="$(check_status "https://www.isitdownrightnow.com/slack.com.html")"
    status_atlassian="$(check_status "https://www.isitdownrightnow.com/atlassian.com.html")"
    status_zoom="$(check_status "https://www.isitdownrightnow.com/zoom.us.html")"
    status_side="$(check_status "https://www.isitdownrightnow.com/side.com.html")"
  }

  get_service_statuses
  get_site_statuses
}

#######################################
# Caltrain data + dialog
#######################################

get_caltrain_data() {
  echo "Caltrain countdown: ${caltrain_api_countdown}"

  if (( caltrain_api_countdown == 0 || caltrain_api_countdown == 4 )); then
    if [[ -z "${caltrain_api_key}" ]]; then
      echo "Caltrain API key missing; skipping fetch."
    else
      local url response
      url="http://api.511.org/transit/servicealerts?api_key=${caltrain_api_key}&agency=CT"
      response="$(curl -s "${url}" || true)"

      printf '%s' "${response}" | pbcopy

      cleaned_up_text="$(
        gemini-cli prompt \
          "Please clean up the following text and organize it into a bullet point list with each item on its own line. Remove non-English and weekday-localized noise. Text: $(pbpaste)" \
          --key "${gemini_key}"
      )"

      caltrain_api_countdown=3
      caltrain_api_pull_time="$(date +"%m-%d-%Y %H:%M:%S")"
    fi
  fi

  if [[ -n "${cleaned_up_text:-}" ]]; then
    msg_font="name=Arial-MT,size=18,colour=#FF0000"
  else
    msg_font="name=Arial-MT,size=18"
  fi

  (( caltrain_api_countdown-- ))
}

caltrain_dialog() {
  local api_label dTitle dMessage dButton1 timer dIconDir dBackDir dInfoBox returncode

  if (( caltrain_api_countdown == 0 )); then
    api_label="Running now!"
  else
    api_label="${caltrain_api_countdown} left."
  fi

  sleep 2

  dTitle="Caltrain – Live Transit Times (San Francisco)"
  dMessage=$(
    cat <<EOF
**Next live status update in:** ${api_label} **Last live update:** ${caltrain_api_pull_time}

Caltrain – Any delays will be posted here:
**${cleaned_up_text:-No current alerts available.}**


San Francisco Schedule
EOF
  )

  timer=10
  dButton1="Quit"
  dIconDir="${dialogIconDir}"
  dBackDir="${dialogBackGroundDir}"
  dInfoBox="__Welcome to Side!__\n\n__580 4th St, San Francisco, CA__\n\n(415) 525-4913\n\n__Need Help?__\nhelpdesk@side.com"

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "${msg_font}" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --height 100% \
    --width 100% \
    --background "${dBackDir}" \
    --infobox "${dInfoBox}" \
    --timer "${timer}" \
    --webcontent "https://www.caltrain.com/station/sanfrancisco"

  returncode=$?

  case "${returncode}" in
    0)
      echo "Caltrain dialog: Quit requested."
      pkill -f "[D]ialog" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "Caltrain dialog: Continuing to next slide."
      ;;
  esac
}

#######################################
# BART data + dialog
#######################################

bart_dialog() {
  local timer dTitle dMessage dButton1 dIconDir dBackDir dInfoBox returncode bart_api_label

  if (( bart_api_countdown == 0 )); then
    bart_api_label="Running now!"
  else
    bart_api_label="${bart_api_countdown} left."
  fi

  dTitle="BART – Live Transit Times (Civic Center)"
  dMessage=$(
    cat <<EOF
**Next live status update in:** ${bart_api_label} **Last live update:** ${bart_api_pull_time}

BART current status – any delays will be posted here:
${bart_status:-No current delays}

Civic Center schedule:
**${live_schedule_times:-No live schedule available.}**
EOF
  )

  dButton1="Quit"
  timer="${1:-${dialogTimer}}"
  dIconDir="${dialogIconDir}"
  dBackDir="${dialogBackGroundDir}"
  dInfoBox="__Welcome to Side!__\n\n__580 4th St, San Francisco, CA__\n\n(415) 525-4913\n\n__Need Help?__\nhelpdesk@side.com"

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "${msg_font}" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --height 50% \
    --width 50% \
    --background "${dBackDir}" \
    --infobox "${dInfoBox}" \
    --timer "${timer}" \
    --webcontent "https://www.bart.gov/schedules/eta/CIVC"

  returncode=$?

  case "${returncode}" in
    0)
      echo "BART dialog: Quit requested."
      pkill -f "[D]ialog" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "BART dialog: Continuing to next slide."
      ;;
  esac
}

get_bart_data() {
  get_bart_status() {
    local bsa_url bsa_response
    bsa_url="https://api.bart.gov/api/bsa.aspx?cmd=bsa&key=${BART_API_KEY}&json=y"
    bsa_response="$(curl -s "${bsa_url}" || true)"

    bart_status="$(echo "${bsa_response}" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p')"

    if [[ -n "${bart_status}" ]]; then
      msg_font="name=Arial-MT,size=18,colour=#FF0000"
    else
      msg_font="name=Arial-MT,size=15"
      bart_status="No current delays"
    fi
  }

  get_station_schedule() {
    local api_url response

    api_url="http://api.bart.gov/api/etd.aspx?cmd=etd&orig=CIVC&json=y&key=${BART_API_KEY}"
    response="$(curl -s -L "${api_url}" || true)"

    if echo "${response}" | jq -e '.root.station[0].etd' >/dev/null 2>&1; then
      local get_times
      get_times="$(
        echo "${response}" | jq -r '
          .root.station[0].etd[] |
          if .estimate[0].minutes == "Leaving" then
            "\(.destination): Leaving"
          else
            "\(.destination): \(.estimate[0].minutes) min"
          end
        '
      )"

      live_schedule_times="${get_times}"
    else
      live_schedule_times="Error: Unable to pull live data. Please refer to the website for the current schedule."
    fi
  }

  echo "BART countdown: ${bart_api_countdown}"

  if (( bart_api_countdown == 0 || bart_api_countdown == 4 )); then
    get_bart_status
    get_station_schedule

    bart_api_countdown=3
    bart_api_pull_time="$(date +"%m-%d-%Y %H:%M:%S")"
  fi

  (( bart_api_countdown-- ))
}

#######################################
# Driving / traffic data + dialog
#######################################

driving_traffic_map_dialog() {
  local dTitle dMessage dButton1 timer dIconDir dBackDir dInfoBox returncode

  dTitle="Live Traffic – Drive Time Estimates from Side SF Office"
  dMessage="Map powered by Google. ETAs powered by Apple Maps.\n\nThe left panel shows live estimated driving times from 580 4th St to downtown locations."

  dButton1="Quit"
  timer="${dialogTimer}"
  dIconDir="${dialogIconDir}"
  dBackDir="${dialogBackGroundDir}"
  dInfoBox=$(
    cat <<EOF
__Welcome to Side!__

__580 4th St, San Francisco, CA__

(415) 525-4913

__Need Help?__
[helpdesk@side.com](${dialogHDURL})

- - - - - - - - - 

__🚗 Driving To:__

**Berkeley:** ${Berkeley_time}
**Fremont:** ${Fremont_time}
**Morgan Hill:** ${MorganHill_time}
**Oakland:** ${Oakland_time}
**Palo Alto:** ${PaloAlto_time}
**Pier 39:** ${Pier39_time}
**San Jose:** ${SanJose_time}
**Walnut Creek:** ${WalnutCreek_time}

- - - - - - - - - 

__✈️ Airports:__

**Oakland Intl:** ${OAK_time}
**San Francisco Intl:** ${SFO_time}
**San Jose Intl:** ${SJC_time}
EOF
  )

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=13" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --height 100% \
    --width 100% \
    --background "${dBackDir}" \
    --infobox "${dInfoBox}" \
    --timer "${timer}" \
    --webcontent "https://www.google.com/maps/@37.6139506,-122.4261246,10z/data=!5m1!1e1?entry=ttu"

  returncode=$?

  case "${returncode}" in
    0)
      echo "Driving dialog: Quit requested."
      pkill -f "[D]ialog" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "Driving dialog: Continuing to next slide."
      ;;
  esac
}

get_driving_traffic_data() {
  echo "Fetching driving-time data via Shortcuts..."

  get_travel_time() {
    local shortcut_name="$1"
    osascript <<EOF
      tell application "Shortcuts Events"
        set shortcutResult to run shortcut "${shortcut_name}"
      end tell

      set resultText to ""
      repeat with anItem in shortcutResult
        set resultText to resultText & anItem & " "
      end repeat
      resultText
EOF
  }

  Pier39_time="$(get_travel_time "Travel Time Pier 39")"
  Oakland_time="$(get_travel_time "Travel Time Oakland")"
  Berkeley_time="$(get_travel_time "Travel Time Berkeley")"
  WalnutCreek_time="$(get_travel_time "Travel Time Walnut Creek")"
  Fremont_time="$(get_travel_time "Travel Time Fremont")"
  SanJose_time="$(get_travel_time "Travel Time San Jose")"
  PaloAlto_time="$(get_travel_time "Travel Time Palo Alto")"
  SFO_time="$(get_travel_time "Travel Time SFO")"
  OAK_time="$(get_travel_time "Travel Time OAK")"
  SJC_time="$(get_travel_time "Travel Time SJC")"
  MorganHill_time="$(get_travel_time "Travel Time Morgan Hill")"

  echo "Estimated drive times from Side SF:"
  echo "  Pier 39:       ${Pier39_time}"
  echo "  Oakland:       ${Oakland_time}"
  echo "  Berkeley:      ${Berkeley_time}"
  echo "  Walnut Creek:  ${WalnutCreek_time}"
  echo "  Fremont:       ${Fremont_time}"
  echo "  San Jose:      ${SanJose_time}"
  echo "  Palo Alto:     ${PaloAlto_time}"
  echo "  SFO:           ${SFO_time}"
  echo "  OAK:           ${OAK_time}"
  echo "  SJC:           ${SJC_time}"
  echo "  Morgan Hill:   ${MorganHill_time}"
}

#######################################
# Startup / loading dialog
#######################################

startup_dialog() {
  local dTitle dMessage dButton1 dIconDir dBackDir dInfoBox returncode

  dTitle="Loading data… please wait"
  dMessage="Downloading the latest live information. This may take a moment."
  dButton1="Quit"
  dIconDir="${dialogIconDir}"
  dBackDir="${dialogBackGroundDir}"
  dInfoBox="__Welcome to Side!__\n\n__580 4th St, San Francisco, CA__\n\n(415) 525-4913\n\n__Need Help?__\nhelpdesk@side.com"

  "${dialog_bin}" \
    --title "${dTitle}" \
    --titlefont "${dialogTitleFont}" \
    --message "${dMessage}" \
    --messagefont "name=Arial-MT,size=16" \
    --icon "${dIconDir}" \
    --iconsize 120 \
    --button1text "${dButton1}" \
    --height 100% \
    --width 100% \
    --background "${dBackDir}" \
    --infobox "${dInfoBox}" \
    --webcontent "https://cdn.dribbble.com/users/5436944/screenshots/14793980/media/eb75f36d10810389e8c0ddefb7423e34.gif"

  returncode=$?

  case "${returncode}" in
    0)
      echo "Startup dialog: Quit requested."
      pkill -f "[D]ialog" 2>/dev/null || true
      exit 0
      ;;
    *)
      echo "Startup dialog: Continuing into main loop."
      ;;
  esac
}

#######################################
# Main
#######################################

set_master_variables

echo "MAIN: Ensuring swiftDialog is installed."
install_dialog

echo "MAIN: Initial load – showing startup dialog and priming driving data."
startup_dialog & get_driving_traffic_data
wait

while true; do
  echo "MAIN: Driving slide + BART data."
  driving_traffic_map_dialog & get_bart_data
  wait

  echo "MAIN: BART slide + Caltrain data."
  bart_dialog "${dialogTimer}" & get_caltrain_data
  wait

  echo "MAIN: Caltrain slide + services data."
  caltrain_dialog & get_services_data
  wait

  echo "MAIN: Services slide + driving data."
  services_dialog & get_driving_traffic_data
  wait

  echo "MAIN: Loop complete – restarting sequence."
done




-----OG
#!/bin/bash
## Hackathon 2024
# This script leverages swiftDialog for the dialog and several APIs to pull live data.
# The use of shortcuts and Apple maps is also used for the driving portion
# Setup:
# Create shortcuts for all driving times using the shortcuts app and apple maps
# Get API from BART, 511.org for Caltrain, and Google Gemini
# Full script
# Dialog 1 - "loading dialog" & run all driving time shortcuts
# Dialog 2 - "driving traffic dialog" & Use BART API to get any system alerts along with Civic center schedule
# Dialog 3 - "bart dialog" & Use 511.org API to get system alerts - these alerts come out in a different format, so use Gemini API to "clean up the text and bullet point list the items"
# Dialog 4 - "caltrain dialog" & use isitup.com to get the status of the sites you want to monitor and scim the status pages of the sites to check if there any outages
# Dialog 5 - "system status dialog" & run all driving time shortcutes (same as with the loading dialog)
# An endless loop is put in place so they keep rotating
# A counter loop is put in place so the API are only run once every 3 slides to reduce the API rate limit issues from occuring. 

#Dialog 1: Loading
#Dialog 2: Live Traffic
#Dialog 3: Live Bart
#Dialog 4: Live Caltrain
#Dialog 5: Service Alerts


set_master_variables () {
	
	
	#API Keys
	caltrain_api_key="your 511.org API key"
	gemini_key="your gemini-cli API key"
	BART_API_KEY="your bart API key"
	
	#setting limits
	caltrain_api_countdown=4
	caltrain_api_pull_time=$(date +"%m-%d-%Y %H:%M:%S")
	
  bart_api_countdown=4
	bart_api_pull_time=$(date +"%m-%d-%Y %H:%M:%S")
	
	
	#Dialog
    updatedDialogVersion=2.5.3
	dialog_bin="/usr/local/bin/dialog"
	dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.3/dialog-2.5.3-4785.pkg"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"
    
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
	
	dialogTimer=15 #adjust this - time in seconds - how long do you want each alert to last for
	dialogIconDir="/Library/Application Support/SideIT/finishing.png"
	dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
	dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
	dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
	dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
}

install_dialog () {
	
    if [ -f "$wallpaperDir$wallpaperImg" ]; then
    echo "Wallpaper found, skipping install"
    else
    echo "Installing wallpaper"
    sudo /usr/sbin/installer -pkg "$wallpaperPKGDir" -target /
    fi
    
	
	#Check Dialog version
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
	

}

#######################################
#######################################
###### Get Services Data
# 1. Using isitdown.com - get WWW data, using specific status page, get feature status data
# 2. Put data in variables in print in dialog


services_dialog () {	

dTitle="Service Statuses"
dMessage="Website Statuses are pulled from isitdown.com - these are just for the main website and not the service.\n
Services Statuses are pulled from their respective status pages.\n

Google WWW:  $status_google   |   Service:  $google_status \n\n
Okta WWW:  $status_okta   |   Service:  $okta_status \n\n
Slack WWW:  $status_slack   |   Service:  $slack_status \n\n
Atlassian WWW:  $status_atlassian   |   Service:  $atlassian_status \n\n
Zoom WWW:  $status_zoom   |   Service:  $zoom_status \n\n
Side WWW:  $status_side
"
dButton1="Quit"
timer=$dialogTimer
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dInfoBox="__Welcome to Side!__\n\n
__580 4th St, San Francisco, CA__
\n\n
(415) 525-4913
\n\n
__Need Help?__  
[helpdesk@side.com]($dialogHDURL)"

get_driving_traffic_data &

	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
		--message "$dMessage" \
		--alignment center \
		--messagefont "name=Arial-MT,size=20" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
		--height 100% \
		--width 100% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
        --timer "$timer" \
		--webcontent "https://i.gifer.com/PYHc.gif" 
		#--blurscreen
 
	
	)		
	
	#Button pressed Stuff
			returncode=$?
	
	
	case ${returncode} in
				    0)  echo "Pressed Button 1: QUIT"
					kill $dialog_pid 2>/dev/null || echo "Dialog process not found or already terminated."
					exit 0
	
				        ;;
		
				    *)  echo "Doing nothing, next slide"


				        ;;
				esac
	
}




get_services_data () {

	get_service_statuses () {

		google_status_pull() {
		    # Fetch the Google Workspace Status Dashboard
		    STATUS_PAGE=$(curl -s https://www.google.com/appsstatus/)

		    # Check for the presence of known issue indicators
		    if echo "$STATUS_PAGE" | grep -q 'class="status yellow"' || echo "$STATUS_PAGE" | grep -q 'class="status red"'; then
		        echo "Google Workspace services are experiencing issues."
		        google_status="Experiencing issues"
		    else
		        echo "Google Workspace services appear to be operating normally."
		        google_status="✅"
		    fi
		}

		okta_status_pull () {
		    # Fetch Okta status page JSON
		    STATUS=$(curl -s https://status.okta.com/api/v2/status.json)

		    # Check if there's any incident or maintenance
		    if echo "$STATUS" | grep -q '"status":"active"'; then
		        echo "Okta is experiencing active incidents."
		        okta_status="Okta is experiencing issues."
		    elif echo "$STATUS" | grep -q '"status":"degraded_performance"'; then
		        echo "Okta is experiencing degraded performance."
		        okta_status="Experiencing issues"
		    else
		        echo "Okta services appear to be operational."
		        okta_status="✅"
		    fi
		}

		slack_status_pull () {
		    # Scrape the Slack status page
		    PAGE=$(curl -s https://slack-status.com/)

		    # Search for known keywords in the status page content
		    if echo "$PAGE" | grep -q "Some users may be having trouble sending messages"; then
		        echo "Experiencing trouble sending messages."
		        slack_status="Experiencing trouble sending messages"
		    elif echo "$PAGE" | grep -q "Some users may be having trouble sending files"; then
		        echo "Experiencing trouble sending files."
		        slack_status="Experiencing trouble sending files"
		    elif echo "$PAGE" | grep -q "Some users may be having trouble loading threads"; then
		        echo "Experiencing trouble loading threads."
		        slack_status="Experiencing trouble loading threads"
		    else
		        echo "Slack status appears normal."
		        slack_status="✅"
		    fi

		    # Final Status Display
		    echo "Final Slack Status: $slack_status"
		}

		zoom_status_pull () {
		    # Fetch Zoom status page JSON
		    STATUS=$(curl -s https://api.zoom.us/v2/metrics/status)

		    # Extract the status using jq
		    SERVICE_STATUS=$(echo "$STATUS" | jq -r '.status.description')

		    # Display the current status
		    echo "Zoom Status: $SERVICE_STATUS"

		    # Check for active incidents
		    INCIDENTS=$(echo "$STATUS" | jq -r '.incidents | length')

		    # Ensure INCIDENTS is set to 0 if not found or empty
		    INCIDENTS=${INCIDENTS:-0}

		    if [ "$INCIDENTS" -gt 0 ]; then
		        echo "There are $INCIDENTS active incidents on Zoom."
		        zoom_status="Experiencing $INCIDENTS"
		    else
		        echo "Zoom is fully operational."
		        zoom_status="✅"
		    fi
		}

		atlassian_status_pull () {
		    # Fetch Atlassian status page JSON
		    STATUS=$(curl -s https://api.status.atlassian.com/1.0/status)

		    # Extract the overall status using jq
		    SERVICE_STATUS=$(echo "$STATUS" | jq -r '.status.description')

		    # Display the current status
		    echo "Atlassian Status: $SERVICE_STATUS"

		    # Check for active incidents
		    INCIDENTS=$(echo "$STATUS" | jq -r '.incidents | length')

		    # Ensure INCIDENTS is set to 0 if not found or empty
		    INCIDENTS=${INCIDENTS:-0}

		    if [ "$INCIDENTS" -gt 0 ]; then
		        echo "There are $INCIDENTS active incidents on Atlassian services."
		        atlassian_status="Experiencing $INCIDENTS"
		    else
		        echo "Atlassian is fully operational."
		        atlassian_status="✅"
		    fi
		}

		#get info
		google_status_pull
		okta_status_pull
		slack_status_pull
		zoom_status_pull
		atlassian_status_pull

		echo "Status: "
		echo $google_status
		echo $okta_status
		echo $slack_status
		echo $zoom_status
		echo $atlassian_status

	}

	get_site_statuses () {

		# Function to check service status
		check_status() {
		    local service_name="$1"
		    local url="$2"
		    local response=$(curl -s "$url")

		    if echo "$response" | grep -q "is UP"; then
		        echo "✅"
		    elif echo "$response" | grep -q "is DOWN"; then
		        echo "is DOWN"
		    else
		        echo "Status - Unknown"
		    fi
		}

		# Check Google
		status_google=$(check_status "Google" "https://www.isitdownrightnow.com/google.com.html")

		# Check Okta
		status_okta=$(check_status "Okta" "https://www.isitdownrightnow.com/okta.com.html")

		# Check Slack
		status_slack=$(check_status "Slack" "https://www.isitdownrightnow.com/slack.com.html")

		# Check Atlassian
		status_atlassian=$(check_status "Atlassian" "https://www.isitdownrightnow.com/atlassian.com.html")

		# Check Zoom
		status_zoom=$(check_status "Zoom" "https://www.isitdownrightnow.com/zoom.us.html")

		#Check Side
		status_side=$(check_status "Side" "https://www.isitdownrightnow.com/side.com.html")

		echo "Results: "
		echo $status_google
		echo $status_okta
		echo $status_slack
		echo $status_atlassian
		echo $status_zoom
		echo $status_side
	}
	
	get_service_statuses
	get_site_statuses

wait $services_dialog_pid
}



#######################################
#######################################
###### Get Caltrain Data
# 1. Using 511.org API, pull Caltrain system alerts
# 2. Alerts come in the form of gibberish, use Gemini API to make an AI call to clean up alert
# 3. Alert is cleaned up and put in variable, variable is printed in dialog
# 3. Using --webcontent key, we also display barts website to how SF live data


get_caltrain_data () {

	echo "caltrain_api_countdown: "$caltrain_api_countdown	

	  # When countdown reaches 0, run the special command and reset the countdown
	  if (($caltrain_api_countdown == 0 || $caltrain_api_countdown == 4)); then
	    echo "Running special command on loop $i"
	   
	   
		# Ensure the API key is not empty
		if [ -z "$caltrain_api_key" ]; then
		    echo "API key is missing!"
		    exit 1
		fi

		# Define the API endpoint
		#url="http://api.511.org/transit/servicealerts?api_key=$caltrain_api_key&agency=CT"

		# Debugging: Print the API key and URL
		echo "Requesting URL: $url"

		# Use curl to make the request and capture the response
		response=$(curl -s "$url")

		#echo "Response"
		#echo $response

		echo "$response" | pbcopy

		echo "pasting: $(pbpaste)"

		cleaned_up_text=$(gemini-cli prompt "Please clean up the following text and organize it into a bullet point list with each item separated by new lines, removing any extraneous information and only leave the list items in english. Make sure the items are separeted in new lines in bullet point order and all non-english is removed. Remove anything with local week day. Here’s the text: $(pbpaste)" --key $gemini_key)
	   
	    caltrain_api_countdown=3 # Reset the countdown
		caltrain_api_pull_time=$(date +"%m-%d-%Y %H:%M:%S")
		echo "Time pull: "$caltrain_api_pull_time
	  fi

	
	echo "Cleaned text"
	echo "$cleaned_up_text"
	
	echo "Time pull: "$caltrain_api_pull_time


	if [ -n "$cleaned_up_text" ]; then
		#yes text
		msg_font="name=Arial-MT,size=18,colour=#FF0000"
	else
		#no text
		msg_font="name=Arial-MT,size=18"
	fi
let caltrain_api_countdown=$caltrain_api_countdown-1
 wait $bart_dialog_pid
	
}





caltrain_dialog () {
	
if [[ $caltrain_api_countdown -eq 0 ]]; then
api_label="Running Now!"
else
api_label="$caltrain_api_countdown left."
fi


	sleep 2

dTitle="Caltrain - Live Transit Times From San Francisco"
dMessage="**Next live status update in:** $api_label **Last live update:** $caltrain_api_pull_time \n\n
Caltrain - Any delays will be posted here:\n
**$cleaned_up_text** \n\n
\n\n


San Francisco Schedule"


timer=10 # 60 seconds * 10 min = 600
dButton1="Quit"
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dInfoBox="__Welcome to Side!__\n\n
__580 4th St, San Francisco, CA__
\n\n
(415) 525-4913
\n\n
__Need Help?__  
helpdesk@side.com"

	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
		--message "$dMessage" \
		--messagefont "$msg_font" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
		--height 100% \
		--width 100% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
	    --timer "$timer" \
		--webcontent "https://www.caltrain.com/station/sanfrancisco" 
	    #--blurscreen

	)
		
		#Button pressed Stuff
				returncode=$?
				
				case ${returncode} in
							    0)  echo "Pressed Button 1: QUIT"
								killall Dialog
								exit 1
	
							        ;;
		
							    *)  echo "Doing nothing, next slide"


							        ;;
							esac


}






#######################################
#######################################
###### Get BART Data
# 1. Using Bart API, we pull any system alerts and CIVIC station train times
# 2. If there are delays, we change the message font to highlight the delay or alert
# 3. Using --webcontent key, we also display barts website to how CIVIC live data

bart_dialog () {
	echo "launching bart dialog"
	
	if [[ $bart_api_countdown -eq 0 ]]; then
	bart_api_label="Running Now!"
	else
	bart_api_label="$bart_api_countdown left."
	fi

dTitle="BART - Live Transit Times From Civic Center"
dMessage="**Next live status update in:** $bart_api_label **Last live update:** $bart_api_pull_time \n\n

BART Current Status - Any delays will be posted here:\n
$bart_status \n\n

Civic Center Schedule: \n
**$live_schedule_times**"
dButton1="Quit"
timer=$1
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dInfoBox="__Welcome to Side!__\n\n
__580 4th St, San Francisco, CA__
\n\n
(415) 525-4913
\n\n
__Need Help?__  
helpdesk@side.com"


userTimeSelection=$(${dialog_bin} \
    --title "$dTitle" \
	--titlefont "$dialogTitleFont" \
	--message "$dMessage" \
	--messagefont "$msg_font" \
    --icon "$dIconDir" \
	--iconsize 120 \
    --button1text "$dButton1" \
	--height 50% \
	--width 50% \
	--background "$dBackDir" \
	--infobox "$dInfoBox" \
    --timer "$timer" \
	--webcontent "https://www.bart.gov/schedules/eta/CIVC" 
    #--blurscreen


)
	
	#Button pressed Stuff
			returncode=$?
		
	
	case ${returncode} in
			    0)  echo "Pressed Button 1: QUIT"
			    echo "Pressed Button 1: QUIT"
				killall Dialog
			              exit 0 


			        ;;
	
			    *)  echo "Doing nothing, next slide"


			        ;;
			esac

}




get_bart_data () {
	echo "get_bart_data function start"
	
	get_bart_status () {
		echo "get_bart_status nested function"
		
		sleep 2
		BSA_URL="https://api.bart.gov/api/bsa.aspx?cmd=bsa&key=${BART_API_KEY}&json=y"

		# Fetch service advisories
		bsa_response=$(curl -s "$BSA_URL")

		# Display the full response for troubleshooting
		echo "Full BART API Response:"
		echo "$bsa_response"

		sleep 3
		# Extract advisories text using sed for cdata-section
		echo "BART Service Advisories:"
		echo "$bsa_response" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p'
		bart_status=$(echo "$bsa_response" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p')
	
		sleep 2
	
		if [ -n "$bart_status" ]; then
		  msg_font="name=Arial-MT,size=18,colour=#FF0000"
		else
		  msg_font="name=Arial-MT,size=15"
		  bart_status="No current delays"
		fi
	
	
	}

	get_station_schedule () {
	echo "get_station_schedule nested function"

	# Define the BART API URL for live departures from Civic Center station (CIVC)
	API_URL="http://api.bart.gov/api/etd.aspx?cmd=etd&orig=CIVC&json=y&key=${BART_API_KEY}"

	# Make the API request using curl and follow redirects
	response=$(curl -s -L "$API_URL")

	# Check if the response is valid (not empty)
	if [[ -z "$response" ]]; then
	    echo "Error: No response from the API."
	    exit 1
	fi

	# Print the raw response to debug and verify it's valid JSON
	echo "Raw API Response:"
	echo "$response"

	# Check if 'etd' data exists in the response
	if echo "$response" | jq -e '.root.station[0].etd' >/dev/null; then
	    # Get tidy times (without quotes and properly formatted)
	    get_times=$(echo "$response" | jq -r '.root.station[0].etd[] | 
	      if .estimate[0].minutes == "Leaving" then
	        "\(.destination): Leaving"
	      else
	        "\(.destination): \(.estimate[0].minutes) min"
	      end')

	    # Print each departure time in a clean list format
	    echo "Upcoming Train Departures:"
		live_schedule_times=""
		for time in "$get_times"; do
		    live_schedule_times+="$time"$'\n'
		done
		
		echo "Travis logs:"
		echo "$live_schedule_times"
		
	else
	    echo "Error: No ETD (estimated departure) data available in the response."
		live_schedule_times="Error: Couldn't pull live data. Please refer to website for current schedule."
		echo "Pull live schedule before pushing to dialog: "$live_schedule_times
	fi

	
	}
	
	
	echo "bart_api_countdown: "$bart_api_countdown

	# Deduct 1 from the countdown
	
	
	echo "updated bart_api_countdown: "$bart_api_countdown

	  # When countdown reaches 0, run the special command and reset the countdown
	  if ((bart_api_countdown == 0 || bart_api_countdown == 4)); then
	    echo "Getting BART data $i"
	
	get_bart_status
	get_station_schedule
	
    bart_api_countdown=3 # Reset the countdown
	bart_api_pull_time=$(date +"%m-%d-%Y %H:%M:%S")
  	fi
	
	let bart_api_countdown=$bart_api_countdown-1
	
	#get_bart_status
	#get_station_schedule
	
	echo "Bart Data Pulled: "
	echo "Bart Status: "$bart_status
	echo "CIVIC Times: "$live_schedule_times
	echo "MSG Font: "$msg_font
	echo "moving onto dialog"
	
	wait $driving_traffic_map_pid
	
}





#######################################
#######################################
###### Get Live Traffic Data
# 1. Using Apple Shortcuts, a shortcut was made for every destination
# 2. Apple Script runs the shortcut and puts the ETA in clipboard and that is placed in a variable
# 3. The variable is then printed in the dialog
# 4. A live map of maps.google.com howing traffic patters and location is displaced via --webcontent key

driving_traffic_map_dialog () {
	echo "launching driving dialog"
	
dTitle="Live Traffic! Drive Time Estimations From Side Office."
dMessage="Map Powered by Google. ETA's Powered By Apple Maps.\n\n
The list on the left panel shows live estimated driving time from 580 4th St to those downtown locatons." 
dButton1="Quit"
timer=$dialogTimer
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dInfoBox="__Welcome to Side!__\n\n
__580 4th St, San Francisco, CA__
\n\n
(415) 525-4913
\n\n
__Need Help?__  
[helpdesk@side.com]($dialogHDURL)\n\n
\n\n
- - - - - - - - - 
__🚗 Driving To:__\n\n
**Berkeley:** $Berkeley_time\n
**Fremont:** $Fremont_time\n
**Morgan Hill:** $MorganHill_time\n
**Oakland:** $Oakland_time\n
**Palo Alto:** $PaloAlto_time\n
**Pier 39:** $Pier39_time\n
**San Jose:** $SanJose_time\n
**Walnut Creek:** $WalnutCreek_time\n\n
\n\n
- - - - - - - - - 
\n\n
__✈️ Airports:__\n\n
**Oakland Intl:** $OAK_time\n
**San Francisco Intl:** $SFO_time\n
**San Jose Intl:** $SJC_time"


	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
		--message "$dMessage" \
		--messagefont "name=Arial-MT,size=13" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
		--height 100% \
		--width 100% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
        --timer "$timer" \
		--webcontent "https://www.google.com/maps/@37.6139506,-122.4261246,10z/data=!5m1!1e1?entry=ttu&g_ep=EgoyMDI0MTExMS4wIKXMDSoASAFQAw%3D%3D" 
	    #--blurscreen
        
	
	)		
	
	#Button pressed Stuff
			returncode=$?
			
	case ${returncode} in
			    0)  echo "Pressed Button 1: QUIT"
				killall Dialog
				exit 1

			        ;;
	
			    *)  echo "Doing nothing, next slide"


			        ;;
			esac
	
}



get_driving_traffic_data () {
	echo "gettiing driving data"

	get_travel_time () {
	    local shortcut_name=$1  # Take shortcut name as a parameter

	    # Run the AppleScript for each shortcut
	    result=$(osascript <<EOF
	    tell application "Shortcuts Events"
	        set shortcutResult to run shortcut "$shortcut_name"
	    end tell

	    -- Initialize an empty string to hold the combined result
	    set resultText to ""

	    -- Iterate through each item in shortcutResult and concatenate them into resultText
	    repeat with anItem in shortcutResult
	        -- Add each item followed by a space to resultText
	        set resultText to resultText & anItem & " "
	    end repeat

	    -- Return the concatenated result as a string
	    resultText
EOF
	)

	    echo "$result"
	}

	# Get individual travel times for each location and store them in variables
	Pier39_time=$(get_travel_time "Travel Time Pier 39")
	Oakland_time=$(get_travel_time "Travel Time Oakland")
	Berkeley_time=$(get_travel_time "Travel Time Berkeley")
	WalnutCreek_time=$(get_travel_time "Travel Time Walnut Creek")
	Fremont_time=$(get_travel_time "Travel Time Fremont")
	SanJose_time=$(get_travel_time "Travel Time San Jose")
	PaloAlto_time=$(get_travel_time "Travel Time Palo Alto")
	SFO_time=$(get_travel_time "Travel Time SFO")
	OAK_time=$(get_travel_time "Travel Time OAK")            # Added OAK
	SJC_time=$(get_travel_time "Travel Time SJC")            # Added SJC
	MorganHill_time=$(get_travel_time "Travel Time Morgan Hill") # Added Morgan Hill

	# Now you can use the variables individually in different parts of the script
	# For example, echoing the times:
	echo "Estimted drive time from Side office to:"
	echo "Pier 39 Time: $Pier39_time"
	echo "Oakland Time: $Oakland_time"
	echo "Berkeley Time: $Berkeley_time"
	echo "Walnut Creek Time: $WalnutCreek_time"
	echo "Fremont Time: $Fremont_time"
	echo "San Jose Time: $SanJose_time"
	echo "Palo Alto Time: $PaloAlto_time"
	echo "SFO Time: $SFO_time"
	echo "OAK Time: $OAK_time"   # Display OAK time
	echo "SJC Time: $SJC_time"   # Display SJC time
	echo "Morgan Hill Time: $MorganHill_time"  # Display Morgan Hill time
	



	if ps -p $services_dialog_pid > /dev/null; then
	        echo "services_dialog is still running, waiting..."
	        wait $services_dialog_pid  # Wait for the process to finish
	    else
	        echo "services_dialog has finished, proceeding..."
	        # Continue to the next step (or code)
	    fi

}





startup_dialog () {
dTitle="Loading data... Please wait"
dMessage="Currently downloading the latest information, please wait..."
dButton1="Quit"
#timer=60
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dInfoBox="__Welcome to Side!__\n\n
__580 4th St, San Francisco, CA__
\n\n
(415) 525-4913
\n\n
__Need Help?__  
helpdesk@side.com"



# Display the dialog
    userTimeSelection=$(${dialog_bin} \
        --title "$dTitle" \
        --titlefont "$dialogTitleFont" \
        --message "$dMessage" \
        --messagefont "$msg_font" \
        --icon "$dIconDir" \
        --iconsize 120 \
        --button1text "$dButton1" \
        --height 100% \
        --width 100% \
        --background "$dBackDir" \
        --infobox "$dInfoBox" \
        --timer "$timer" \
        --webcontent "https://cdn.dribbble.com/users/5436944/screenshots/14793980/media/eb75f36d10810389e8c0ddefb7423e34.gif" 
        #--blurscreen
	)
		
		case ${returncode} in
				    0)  echo "Pressed Button 1: QUIT"
					killall Dialog
					exit 1
	
				        ;;
		
				    *)  echo "Doing nothing, next slide"


				        ;;
				esac
    

# Wait for the background process to finish and then kill the dialog
wait $driving_traffic_data_pid # Wait for the background task to finish
sleep 2
killall dialog  # Kill the dialog once the task is done
}



#kick it off
set_master_variables

echo "MAIN: Installing Dialog"
install_dialog

echo "MAIN: Launch startup dialog and download traffic data"
#launch loading dialog and get drivin traffic data
startup_dialog & get_driving_traffic_data

while true; do

	#echo "Start loop"
	#echo "MAIN: Launch driving traffic dialog and download bart data"
    ## Load driving dialog and get traffic data
    driving_traffic_map_dialog & get_bart_data

	echo "MAIN: Launch bart dialog and download caltrain data"
    # Load BART dialog and get caltrain data
    bart_dialog & get_caltrain_data 
	
	echo "MAIN: Launch caltrain dialog and download services data"
	#Load Caltrain dialog and get services data
	caltrain_dialog & get_services_data 
	
	echo "MAIN: Launch services dialog and download driving data"
	#Load Services dialog and get traffic data
	services_dialog & get_driving_traffic_data 
	
	#loop - start over from driving traffic
	echo "done, loop back to traffic dialog"

	
done
