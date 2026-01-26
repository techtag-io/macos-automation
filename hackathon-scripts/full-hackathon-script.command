#!/bin/bash

################################################################################
# Transit Hub Information Dashboard
# Description: Comprehensive transit and service monitoring dashboard that
#              rotates between traffic, BART, Caltrain, and service status
#              displays with live API data updates
################################################################################

set -euo pipefail

################################################################################
# Global Configuration Constants
################################################################################

# API Keys and Endpoints
readonly CALTRAIN_API_KEY="key"
readonly GEMINI_API_KEY="key"
readonly BART_API_KEY="key"

readonly CALTRAIN_API_URL="http://api.511.org/transit/servicealerts?api_key=${CALTRAIN_API_KEY}&agency=CT"
readonly BART_BSA_URL="https://api.bart.gov/api/bsa.aspx?cmd=bsa&key=${BART_API_KEY}&json=y"
readonly BART_ETD_URL="http://api.bart.gov/api/etd.aspx?cmd=etd&orig=CIVC&json=y&key=${BART_API_KEY}"

# API Rate Limiting Configuration
readonly API_REFRESH_CYCLES=3
CALTRAIN_API_COUNTDOWN=4  # Start with immediate fetch
BART_API_COUNTDOWN=4      # Start with immediate fetch

# Cached Data Storage
CALTRAIN_ALERTS=""
CALTRAIN_LAST_UPDATE=""
BART_STATUS=""
BART_SCHEDULE=""
BART_LAST_UPDATE=""

# Service Status Storage
GOOGLE_WWW_STATUS=""
GOOGLE_SERVICE_STATUS=""
OKTA_WWW_STATUS=""
OKTA_SERVICE_STATUS=""
SLACK_WWW_STATUS=""
SLACK_SERVICE_STATUS=""
ATLASSIAN_WWW_STATUS=""
ATLASSIAN_SERVICE_STATUS=""
ZOOM_WWW_STATUS=""
ZOOM_SERVICE_STATUS=""
SIDE_WWW_STATUS=""
SIDE_APP_STATUS=""

# Traffic Data Storage
declare -A TRAFFIC_TIMES=(
    ["Berkeley"]=""
    ["Fremont"]=""
    ["MorganHill"]=""
    ["Oakland"]=""
    ["PaloAlto"]=""
    ["Pier39"]=""
    ["SanJose"]=""
    ["WalnutCreek"]=""
    ["OAK"]=""
    ["SFO"]=""
    ["SJC"]=""
)

# swiftDialog Configuration
readonly DIALOG_VERSION="2.5.3"
readonly DIALOG_BUILD="4785"
readonly DIALOG_BIN="/usr/local/bin/dialog"
readonly DIALOG_APP="/Library/Application Support/Dialog/Dialog.app"
readonly DIALOG_DOWNLOAD_URL="https://github.com/swiftDialog/swiftDialog/releases/download/v${DIALOG_VERSION}/dialog-${DIALOG_VERSION}-${DIALOG_BUILD}.pkg"
readonly DIALOG_INSTALL_DIR="/usr/local/"
readonly DIALOG_PKG_NAME="swiftDialog.pkg"

# Asset Paths
readonly WALLPAPER_DIR="/Library/Application Support/wallpaper/"
readonly WALLPAPER_FILE="desktopwallpaper.jpg"
readonly WALLPAPER_PKG="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
readonly ICON_PATH="/Library/Application Support/SideIT/finishing.png"

# Dialog Styling
readonly TITLE_FONT="name=Arial-MT,colour=#CE87C1,size=30"
readonly MESSAGE_FONT_NORMAL="name=Arial-MT,size=15"
readonly MESSAGE_FONT_ALERT="name=Arial-MT,size=18,colour=#FF0000"

# Display Settings
readonly DISPLAY_TIMER=15  # seconds per slide

# Organization Information
readonly ORG_NAME="Side, Inc"
readonly ORG_ADDRESS="580 4th St, San Francisco, CA"
readonly ORG_PHONE="(415) 525-4913"
readonly ORG_EMAIL="helpdesk@side.com"
readonly HELPDESK_URL="https://sideinc.freshservice.com/support/catalog/items/131"

################################################################################
# Dependency Management Functions
################################################################################

install_wallpaper() {
    local wallpaper_path="${WALLPAPER_DIR}${WALLPAPER_FILE}"
    
    if [ -f "${wallpaper_path}" ]; then
        echo "[INFO] Wallpaper already installed"
        return 0
    fi
    
    if [ ! -f "${WALLPAPER_PKG}" ]; then
        echo "[WARNING] Wallpaper package not found"
        return 1
    fi
    
    echo "[INFO] Installing wallpaper..."
    sudo /usr/sbin/installer -pkg "${WALLPAPER_PKG}" -target / 2>/dev/null
    [ -f "${wallpaper_path}" ] && echo "[SUCCESS] Wallpaper installed"
}

get_installed_dialog_version() {
    if [ -f "${DIALOG_BIN}" ] && [ -d "${DIALOG_APP}" ]; then
        defaults read "${DIALOG_APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo ""
    else
        echo ""
    fi
}

install_swift_dialog() {
    local installed_version
    local temp_pkg_path="${DIALOG_INSTALL_DIR}${DIALOG_PKG_NAME}"
    
    installed_version=$(get_installed_dialog_version)
    
    if [ "${installed_version}" = "${DIALOG_VERSION}" ]; then
        echo "[INFO] swiftDialog ${DIALOG_VERSION} already installed"
        return 0
    fi
    
    echo "[INFO] Installing swiftDialog ${DIALOG_VERSION}..."
    
    if ! sudo /usr/bin/curl -L "${DIALOG_DOWNLOAD_URL}" -o "${temp_pkg_path}" 2>/dev/null; then
        echo "[ERROR] Failed to download swiftDialog"
        return 1
    fi
    
    if ! sudo /usr/sbin/installer -pkg "${temp_pkg_path}" -target / 2>/dev/null; then
        echo "[ERROR] Failed to install swiftDialog"
        sudo rm -f "${temp_pkg_path}"
        return 1
    fi
    
    sleep 5
    sudo rm -f "${temp_pkg_path}"
    
    echo "[SUCCESS] swiftDialog ${DIALOG_VERSION} installed"
}

################################################################################
# Service Status Functions
################################################################################

check_google_service_status() {
    local status_page
    
    status_page=$(curl -s --connect-timeout 10 https://www.google.com/appsstatus/ 2>/dev/null)
    
    if echo "${status_page}" | grep -q 'class="status yellow"\|class="status red"'; then
        GOOGLE_SERVICE_STATUS="Experiencing issues"
    else
        GOOGLE_SERVICE_STATUS="✅"
    fi
}

check_okta_service_status() {
    local status
    
    status=$(curl -s --connect-timeout 10 https://status.okta.com/api/v2/status.json 2>/dev/null)
    
    if echo "${status}" | grep -q '"status":"active"\|"status":"degraded_performance"'; then
        OKTA_SERVICE_STATUS="Experiencing issues"
    else
        OKTA_SERVICE_STATUS="✅"
    fi
}

check_slack_service_status() {
    local page
    
    page=$(curl -s --connect-timeout 10 https://slack-status.com/ 2>/dev/null)
    
    if echo "${page}" | grep -q "Some users may be having trouble"; then
        SLACK_SERVICE_STATUS="Experiencing issues"
    else
        SLACK_SERVICE_STATUS="✅"
    fi
}

check_zoom_service_status() {
    local status incidents
    
    status=$(curl -s --connect-timeout 10 https://api.zoom.us/v2/metrics/status 2>/dev/null)
    incidents=$(echo "${status}" | jq -r '.incidents | length' 2>/dev/null || echo "0")
    
    if [ "${incidents}" -gt 0 ]; then
        ZOOM_SERVICE_STATUS="Experiencing ${incidents} incidents"
    else
        ZOOM_SERVICE_STATUS="✅"
    fi
}

check_atlassian_service_status() {
    local status incidents
    
    status=$(curl -s --connect-timeout 10 https://api.status.atlassian.com/1.0/status 2>/dev/null)
    incidents=$(echo "${status}" | jq -r '.incidents | length' 2>/dev/null || echo "0")
    
    if [ "${incidents}" -gt 0 ]; then
        ATLASSIAN_SERVICE_STATUS="Experiencing ${incidents} incidents"
    else
        ATLASSIAN_SERVICE_STATUS="✅"
    fi
}

check_side_app_status() {
    local http_code
    
    http_code=$(curl -s -w "%{http_code}" -o /dev/null --connect-timeout 10 \
                https://agent.sideinc.com/txm/api/health 2>/dev/null)
    
    if [ "${http_code}" -eq 200 ]; then
        SIDE_APP_STATUS="✅"
    else
        SIDE_APP_STATUS="HTTP ${http_code}"
    fi
}

check_website_status() {
    local service_name="$1"
    local url="$2"
    local response
    
    response=$(curl -s --connect-timeout 10 "${url}" 2>/dev/null)
    
    if echo "${response}" | grep -q "is UP"; then
        echo "✅"
    elif echo "${response}" | grep -q "is DOWN"; then
        echo "DOWN"
    else
        echo "Unknown"
    fi
}

fetch_all_service_statuses() {
    echo "[INFO] Fetching service statuses..."
    
    # Service-specific status checks
    check_google_service_status &
    check_okta_service_status &
    check_slack_service_status &
    check_zoom_service_status &
    check_atlassian_service_status &
    check_side_app_status &
    
    # Website availability checks
    GOOGLE_WWW_STATUS=$(check_website_status "Google" "https://www.isitdownrightnow.com/google.com.html") &
    OKTA_WWW_STATUS=$(check_website_status "Okta" "https://www.isitdownrightnow.com/okta.com.html") &
    SLACK_WWW_STATUS=$(check_website_status "Slack" "https://www.isitdownrightnow.com/slack.com.html") &
    ATLASSIAN_WWW_STATUS=$(check_website_status "Atlassian" "https://www.isitdownrightnow.com/atlassian.com.html") &
    ZOOM_WWW_STATUS=$(check_website_status "Zoom" "https://www.isitdownrightnow.com/zoom.us.html") &
    SIDE_WWW_STATUS=$(check_website_status "Side" "https://www.isitdownrightnow.com/side.com.html") &
    
    wait
    echo "[SUCCESS] Service statuses updated"
}

################################################################################
# Caltrain Data Functions
################################################################################

process_alerts_with_ai() {
    local raw_alerts="$1"
    local cleaned_alerts
    
    if [ -z "${raw_alerts}" ]; then
        echo ""
        return 0
    fi
    
    if ! command -v gemini-cli &> /dev/null; then
        echo "${raw_alerts}"
        return 0
    fi
    
    cleaned_alerts=$(gemini-cli prompt "Please clean up the following text and organize it into a bullet point list with each item separated by new lines, removing any extraneous information and only leave the list items in English. Remove anything with local week day. Here's the text: ${raw_alerts}" --key "${GEMINI_API_KEY}" 2>/dev/null)
    
    echo "${cleaned_alerts:-${raw_alerts}}"
}

fetch_caltrain_data() {
    ((CALTRAIN_API_COUNTDOWN--)) || true
    
    if [ "${CALTRAIN_API_COUNTDOWN}" -ne 0 ]; then
        echo "[INFO] Using cached Caltrain data (${CALTRAIN_API_COUNTDOWN} cycles remaining)"
        return 0
    fi
    
    echo "[INFO] Fetching live Caltrain alerts..."
    
    local response
    response=$(curl -s --connect-timeout 10 "${CALTRAIN_API_URL}" 2>/dev/null)
    
    if [ -n "${response}" ]; then
        CALTRAIN_ALERTS=$(process_alerts_with_ai "${response}")
        CALTRAIN_LAST_UPDATE=$(date +"%m-%d-%Y %H:%M:%S")
        echo "[SUCCESS] Caltrain data updated at ${CALTRAIN_LAST_UPDATE}"
    else
        CALTRAIN_ALERTS="Unable to retrieve alerts"
        echo "[WARNING] Failed to fetch Caltrain data"
    fi
    
    CALTRAIN_API_COUNTDOWN=${API_REFRESH_CYCLES}
}

################################################################################
# BART Data Functions
################################################################################

fetch_bart_status() {
    local response
    
    response=$(curl -s --connect-timeout 10 "${BART_BSA_URL}" 2>/dev/null)
    
    if [ -n "${response}" ]; then
        BART_STATUS=$(echo "${response}" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p')
        [ -z "${BART_STATUS}" ] && BART_STATUS="No current delays"
    else
        BART_STATUS="Unable to retrieve status"
    fi
}

fetch_bart_schedule() {
    local response
    
    response=$(curl -s -L --connect-timeout 10 "${BART_ETD_URL}" 2>/dev/null)
    
    if [ -z "${response}" ]; then
        BART_SCHEDULE="Unable to retrieve schedule"
        return 1
    fi
    
    if ! echo "${response}" | jq -e '.root.station[0].etd' >/dev/null 2>&1; then
        BART_SCHEDULE="No departure data available"
        return 1
    fi
    
    BART_SCHEDULE=$(echo "${response}" | jq -r '.root.station[0].etd[] | 
        if .estimate[0].minutes == "Leaving" then
            "\(.destination): Leaving"
        else
            "\(.destination): \(.estimate[0].minutes) min"
        end' 2>/dev/null)
    
    [ -z "${BART_SCHEDULE}" ] && BART_SCHEDULE="No trains scheduled"
}

fetch_bart_data() {
    ((BART_API_COUNTDOWN--)) || true
    
    if [ "${BART_API_COUNTDOWN}" -ne 0 ]; then
        echo "[INFO] Using cached BART data (${BART_API_COUNTDOWN} cycles remaining)"
        return 0
    fi
    
    echo "[INFO] Fetching live BART data..."
    
    fetch_bart_status &
    fetch_bart_schedule &
    wait
    
    BART_LAST_UPDATE=$(date +"%m-%d-%Y %H:%M:%S")
    echo "[SUCCESS] BART data updated at ${BART_LAST_UPDATE}"
    
    BART_API_COUNTDOWN=${API_REFRESH_CYCLES}
}

################################################################################
# Traffic Data Functions
################################################################################

get_travel_time() {
    local shortcut_name="$1"
    local result
    
    result=$(osascript 2>/dev/null <<EOF
tell application "Shortcuts Events"
    set shortcutResult to run shortcut "${shortcut_name}"
end tell

set resultText to ""
repeat with anItem in shortcutResult
    set resultText to resultText & anItem & " "
end repeat

resultText
EOF
)
    
    echo "${result:-N/A}"
}

fetch_traffic_data() {
    echo "[INFO] Fetching live traffic data..."
    
    TRAFFIC_TIMES["Pier39"]=$(get_travel_time "Travel Time Pier 39") &
    TRAFFIC_TIMES["Oakland"]=$(get_travel_time "Travel Time Oakland") &
    TRAFFIC_TIMES["Berkeley"]=$(get_travel_time "Travel Time Berkeley") &
    TRAFFIC_TIMES["WalnutCreek"]=$(get_travel_time "Travel Time Walnut Creek") &
    TRAFFIC_TIMES["Fremont"]=$(get_travel_time "Travel Time Fremont") &
    TRAFFIC_TIMES["SanJose"]=$(get_travel_time "Travel Time San Jose") &
    TRAFFIC_TIMES["PaloAlto"]=$(get_travel_time "Travel Time Palo Alto") &
    TRAFFIC_TIMES["MorganHill"]=$(get_travel_time "Travel Time Morgan Hill") &
    TRAFFIC_TIMES["SFO"]=$(get_travel_time "Travel Time SFO") &
    TRAFFIC_TIMES["OAK"]=$(get_travel_time "Travel Time OAK") &
    TRAFFIC_TIMES["SJC"]=$(get_travel_time "Travel Time SJC") &
    
    wait
    echo "[SUCCESS] Traffic data updated"
}

################################################################################
# Dialog Display Functions
################################################################################

show_dialog() {
    local title="$1"
    local message="$2"
    local webcontent="$3"
    local infobox="$4"
    local message_font="${5:-${MESSAGE_FONT_NORMAL}}"
    
    ${DIALOG_BIN} \
        --title "${title}" \
        --titlefont "${TITLE_FONT}" \
        --message "${message}" \
        --messagefont "${message_font}" \
        --icon "${ICON_PATH}" \
        --iconsize 120 \
        --height 100% \
        --width 100% \
        --background "${WALLPAPER_DIR}${WALLPAPER_FILE}" \
        --infobox "${infobox}" \
        --timer "${DISPLAY_TIMER}" \
        --webcontent "${webcontent}" \
        --button1text "Quit" 2>/dev/null
    
    local return_code=$?
    [ "${return_code}" -eq 0 ] && exit 0
}

display_startup_screen() {
    local title="Loading data... Please wait"
    local message="Currently downloading the latest information, please wait..."
    local webcontent="https://cdn.dribbble.com/users/5436944/screenshots/14793980/media/eb75f36d10810389e8c0ddefb7423e34.gif"
    local infobox="__Welcome to ${ORG_NAME}!__\n\n__${ORG_ADDRESS}__\n\n${ORG_PHONE}\n\n__Need Help?__\n${ORG_EMAIL}"
    
    echo "[INFO] Displaying startup screen"
    
    ${DIALOG_BIN} \
        --title "${title}" \
        --titlefont "${TITLE_FONT}" \
        --message "${message}" \
        --messagefont "${MESSAGE_FONT_NORMAL}" \
        --icon "${ICON_PATH}" \
        --iconsize 120 \
        --height 100% \
        --width 100% \
        --background "${WALLPAPER_DIR}${WALLPAPER_FILE}" \
        --infobox "${infobox}" \
        --webcontent "${webcontent}" \
        --button1text "Quit" 2>/dev/null &
    
    local dialog_pid=$!
    
    # Fetch initial data in background
    fetch_traffic_data
    
    # Kill startup dialog
    kill "${dialog_pid}" 2>/dev/null || true
    sleep 1
}

display_traffic_screen() {
    echo "[INFO] Displaying traffic information"
    
    local title="Live Traffic! Drive Time Estimations From Side Office."
    local message="Map Powered by Google. ETA's Powered By Apple Maps.\n\nThe list on the left panel shows live estimated driving time from 580 4th St to those downtown locations."
    local webcontent="https://www.google.com/maps/@37.6139506,-122.4261246,10z/data=!5m1!1e1?entry=ttu"
    local infobox="__Welcome to ${ORG_NAME}!__\n\n__${ORG_ADDRESS}__\n\n${ORG_PHONE}\n\n__Need Help?__\n[${ORG_EMAIL}](${HELPDESK_URL})\n\n- - - - - - - - -\n__🚗 Driving To:__\n\n**Berkeley:** ${TRAFFIC_TIMES[Berkeley]}\n**Fremont:** ${TRAFFIC_TIMES[Fremont]}\n**Morgan Hill:** ${TRAFFIC_TIMES[MorganHill]}\n**Oakland:** ${TRAFFIC_TIMES[Oakland]}\n**Palo Alto:** ${TRAFFIC_TIMES[PaloAlto]}\n**Pier 39:** ${TRAFFIC_TIMES[Pier39]}\n**San Jose:** ${TRAFFIC_TIMES[SanJose]}\n**Walnut Creek:** ${TRAFFIC_TIMES[WalnutCreek]}\n\n- - - - - - - - -\n\n__✈️ Airports:__\n\n**Oakland Intl:** ${TRAFFIC_TIMES[OAK]}\n**San Francisco Intl:** ${TRAFFIC_TIMES[SFO]}\n**San Jose Intl:** ${TRAFFIC_TIMES[SJC]}"
    
    show_dialog "${title}" "${message}" "${webcontent}" "${infobox}" "name=Arial-MT,size=13"
}

display_bart_screen() {
    echo "[INFO] Displaying BART information"
    
    fetch_bart_data
    
    local countdown_label
    [ "${BART_API_COUNTDOWN}" -eq 0 ] && countdown_label="Running Now!" || countdown_label="${BART_API_COUNTDOWN} cycles remaining"
    
    local message_font
    [ -n "${BART_STATUS}" ] && [ "${BART_STATUS}" != "No current delays" ] && message_font="${MESSAGE_FONT_ALERT}" || message_font="${MESSAGE_FONT_NORMAL}"
    
    local title="BART - Live Transit Times From Civic Center"
    local message="**Next live status update in:** ${countdown_label}  **Last live update:** ${BART_LAST_UPDATE}\n\nBART Current Status - Any delays will be posted here:\n${BART_STATUS}\n\nCivic Center Schedule:\n${BART_SCHEDULE}"
    local webcontent="https://www.bart.gov/schedules/eta/CIVC"
    local infobox="__Welcome to ${ORG_NAME}!__\n\n__${ORG_ADDRESS}__\n\n${ORG_PHONE}\n\n__Need Help?__\n${ORG_EMAIL}"
    
    show_dialog "${title}" "${message}" "${webcontent}" "${infobox}" "${message_font}"
}

display_caltrain_screen() {
    echo "[INFO] Displaying Caltrain information"
    
    fetch_caltrain_data
    
    local countdown_label
    [ "${CALTRAIN_API_COUNTDOWN}" -eq 0 ] && countdown_label="Running Now!" || countdown_label="${CALTRAIN_API_COUNTDOWN} cycles remaining"
    
    local message_font
    [ -n "${CALTRAIN_ALERTS}" ] && message_font="${MESSAGE_FONT_ALERT}" || message_font="${MESSAGE_FONT_NORMAL}"
    
    local title="Caltrain - Live Transit Times From San Francisco"
    local message="**Next live status update in:** ${countdown_label}  **Last live update:** ${CALTRAIN_LAST_UPDATE}\n\nCaltrain - Any delays will be posted here:\n${CALTRAIN_ALERTS}\n\n\nSan Francisco Schedule"
    local webcontent="https://www.caltrain.com/station/sanfrancisco"
    local infobox="__Welcome to ${ORG_NAME}!__\n\n__${ORG_ADDRESS}__\n\n${ORG_PHONE}\n\n__Need Help?__\n${ORG_EMAIL}"
    
    show_dialog "${title}" "${message}" "${webcontent}" "${infobox}" "${message_font}"
}

display_services_screen() {
    echo "[INFO] Displaying service status information"
    
    fetch_all_service_statuses
    
    local title="Service Statuses"
    local message="Website Statuses are pulled from isitdown.com - these are just for the main website and not the service.\nServices Statuses are pulled from their respective status pages.\n\n**Google** WWW: ${GOOGLE_WWW_STATUS}   |   Service: ${GOOGLE_SERVICE_STATUS}\n\n**Okta** WWW: ${OKTA_WWW_STATUS}   |   Service: ${OKTA_SERVICE_STATUS}\n\n**Slack** WWW: ${SLACK_WWW_STATUS}   |   Service: ${SLACK_SERVICE_STATUS}\n\n**Atlassian** WWW: ${ATLASSIAN_WWW_STATUS}   |   Service: ${ATLASSIAN_SERVICE_STATUS}\n\n**Zoom** WWW: ${ZOOM_WWW_STATUS}   |   Service: ${ZOOM_SERVICE_STATUS}\n\n**Side** WWW: ${SIDE_WWW_STATUS}   |   Service: ${SIDE_APP_STATUS}"
    local webcontent="https://i.gifer.com/PYHc.gif"
    local infobox="__Welcome to ${ORG_NAME}!__\n\n__${ORG_ADDRESS}__\n\n${ORG_PHONE}\n\n__Need Help?__\n[${ORG_EMAIL}](${HELPDESK_URL})"
    
    show_dialog "${title}" "${message}" "${webcontent}" "${infobox}" "name=Arial-MT,size=20"
}

################################################################################
# Main Execution Loop
################################################################################

main() {
    echo "════════════════════════════════════════════════════════════"
    echo "Transit Hub Information Dashboard - Starting"
    echo "Location: ${ORG_ADDRESS}"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
    
    # Install dependencies
    echo "[STEP 1/2] Installing dependencies..."
    install_wallpaper || echo "[WARNING] Wallpaper installation skipped"
    
    if ! install_swift_dialog; then
        echo "[ERROR] Failed to install swiftDialog"
        exit 1
    fi
    
    if [ ! -x "${DIALOG_BIN}" ]; then
        echo "[ERROR] swiftDialog not found"
        exit 1
    fi
    
    # Display startup and fetch initial data
    echo "[STEP 2/2] Loading initial data..."
    display_startup_screen
    
    # Main display loop
    echo "[INFO] Starting continuous display loop..."
    
    while true; do
        echo "────────────────────────────────────────────────────────────"
        echo "Loop iteration: $(date '+%H:%M:%S')"
        echo "────────────────────────────────────────────────────────────"
        
        # Cycle through all displays
        display_traffic_screen & fetch_bart_data; wait
        display_bart_screen & fetch_caltrain_data; wait
        display_caltrain_screen & fetch_all_service_statuses; wait
        display_services_screen & fetch_traffic_data; wait
        
        sleep 2
    done
}

################################################################################
# Script Execution
################################################################################

# Trap to ensure clean exit
trap 'echo "[INFO] Dashboard stopped"; killall Dialog 2>/dev/null; exit 0' INT TERM

# Execute main function
main "$@"






----OG

#!/bin/bash

#Dialog 1: Loading
#Dialog 2: Live Traffic
#Dialog 3: Live Bart
#Dialog 4: Live Caltrain
#Dialog 5: Service Alerts


set_master_variables () {
	
	
	#API Keys
	caltrain_api_key="key"
	gemini_key="key"
	BART_API_KEY="key"
	
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
Side WWW:  $status_side   |   Service:  $sideapp_status
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
		
		
		sideapp_status_pull () {
		    # Fetch Atlassian status page JSON
		    STATUS=$(curl -s -w "%{http_code}" -o temp_output https://agent.sideinc.com/txm/api/health)

			http_code=${STATUS: -3}
			sideapp_status_result=$(<temp_output)

			if [ "$http_code" -eq 200 ]; then
			    echo "Success: $sideapp_status_result"
				sideapp_status="✅"
			else
			    echo "Experiencing HTTP code $http_code"
				sideapp_status="Experiencing HTTP code $http_code"
			fi
		    
		}

		#get info
		google_status_pull
		okta_status_pull
		slack_status_pull
		zoom_status_pull
		atlassian_status_pull
		sideapp_status_pull

		echo "Status: "
		echo $google_status
		echo $okta_status
		echo $slack_status
		echo $zoom_status
		echo $atlassian_status
		echo $sideapp_status

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
	--height 100% \
	--width 100% \
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
