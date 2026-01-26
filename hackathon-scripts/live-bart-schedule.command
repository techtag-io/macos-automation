#!/bin/bash

################################################################################
# BART Transit Information Display
# Description: Displays live BART transit times and service advisories
#              for the Civic Center station with swiftDialog UI
# Author: Travis Green
################################################################################

set -euo pipefail

################################################################################
# Configuration Constants
################################################################################

# BART API Configuration
readonly BART_API_KEY="api key goes here"
readonly BART_STATION="CIVC"  # Civic Center
readonly BART_BSA_URL="https://api.bart.gov/api/bsa.aspx?cmd=bsa&key=${BART_API_KEY}&json=y"
readonly BART_ETD_URL="http://api.bart.gov/api/etd.aspx?cmd=etd&orig=${BART_STATION}&json=y&key=${BART_API_KEY}"
readonly BART_WEB_URL="https://www.bart.gov/schedules/eta/${BART_STATION}"

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
readonly DISPLAY_TIMER=20  # seconds
readonly API_REFRESH_INTERVAL=30  # seconds between API calls

# Organization Information
readonly ORG_NAME="Side, Inc"
readonly ORG_ADDRESS="580 4th St, San Francisco, CA"
readonly ORG_PHONE="(415) 525-4913"
readonly ORG_EMAIL="helpdesk@side.com"

################################################################################
# Function: install_wallpaper
# Description: Installs desktop wallpaper if not already present
################################################################################
install_wallpaper() {
    local wallpaper_path="${WALLPAPER_DIR}${WALLPAPER_FILE}"
    
    if [ -f "${wallpaper_path}" ]; then
        echo "[INFO] Wallpaper already installed at ${wallpaper_path}"
        return 0
    fi
    
    if [ ! -f "${WALLPAPER_PKG}" ]; then
        echo "[WARNING] Wallpaper package not found at ${WALLPAPER_PKG}"
        return 1
    fi
    
    echo "[INFO] Installing wallpaper..."
    sudo /usr/sbin/installer -pkg "${WALLPAPER_PKG}" -target /
    
    if [ -f "${wallpaper_path}" ]; then
        echo "[SUCCESS] Wallpaper installed successfully"
        return 0
    else
        echo "[ERROR] Wallpaper installation failed"
        return 1
    fi
}

################################################################################
# Function: get_installed_dialog_version
# Description: Retrieves currently installed swiftDialog version
# Returns: Version string or empty if not installed
################################################################################
get_installed_dialog_version() {
    if [ -f "${DIALOG_BIN}" ] && [ -d "${DIALOG_APP}" ]; then
        defaults read "${DIALOG_APP}/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo ""
    else
        echo ""
    fi
}

################################################################################
# Function: install_swift_dialog
# Description: Installs or updates swiftDialog to the specified version
################################################################################
install_swift_dialog() {
    local installed_version
    local temp_pkg_path="${DIALOG_INSTALL_DIR}${DIALOG_PKG_NAME}"
    
    installed_version=$(get_installed_dialog_version)
    
    if [ -n "${installed_version}" ]; then
        echo "[INFO] swiftDialog ${installed_version} currently installed"
        
        if [ "${installed_version}" = "${DIALOG_VERSION}" ]; then
            echo "[INFO] swiftDialog is up to date (${DIALOG_VERSION})"
            return 0
        else
            echo "[INFO] Updating swiftDialog from ${installed_version} to ${DIALOG_VERSION}"
        fi
    else
        echo "[INFO] swiftDialog not found, installing version ${DIALOG_VERSION}"
    fi
    
    # Download swiftDialog
    echo "[INFO] Downloading swiftDialog from ${DIALOG_DOWNLOAD_URL}"
    if ! sudo /usr/bin/curl -L "${DIALOG_DOWNLOAD_URL}" -o "${temp_pkg_path}"; then
        echo "[ERROR] Failed to download swiftDialog"
        return 1
    fi
    
    # Install swiftDialog
    echo "[INFO] Installing swiftDialog..."
    if ! sudo /usr/sbin/installer -pkg "${temp_pkg_path}" -target /; then
        echo "[ERROR] Failed to install swiftDialog"
        sudo rm -f "${temp_pkg_path}"
        return 1
    fi
    
    # Wait for installation to complete
    sleep 5
    
    # Cleanup
    echo "[INFO] Cleaning up installation package..."
    sudo rm -f "${temp_pkg_path}"
    
    # Verify installation
    installed_version=$(get_installed_dialog_version)
    if [ "${installed_version}" = "${DIALOG_VERSION}" ]; then
        echo "[SUCCESS] swiftDialog ${DIALOG_VERSION} installed successfully"
        return 0
    else
        echo "[ERROR] Installation verification failed"
        return 1
    fi
}

################################################################################
# Function: get_bart_service_status
# Description: Retrieves current BART service advisories
# Returns: Service advisory text or empty string if no advisories
################################################################################
get_bart_service_status() {
    local response
    local status
    
    echo "[INFO] Fetching BART service advisories..."
    
    # Fetch service advisories
    response=$(curl -s "${BART_BSA_URL}")
    
    if [ -z "${response}" ]; then
        echo "[WARNING] Empty response from BART API"
        echo ""
        return 1
    fi
    
    # Extract advisory description from JSON
    status=$(echo "${response}" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p')
    
    if [ -n "${status}" ]; then
        echo "[ALERT] Service advisory detected: ${status}"
    else
        echo "[INFO] No service advisories at this time"
    fi
    
    echo "${status}"
}

################################################################################
# Function: get_live_departures
# Description: Retrieves live departure times for the configured station
# Returns: Formatted departure information
################################################################################
get_live_departures() {
    local response
    local departures
    
    echo "[INFO] Fetching live departure times for ${BART_STATION}..."
    
    # Fetch live departure data
    response=$(curl -s -L "${BART_ETD_URL}")
    
    if [ -z "${response}" ]; then
        echo "[ERROR] No response from BART ETD API"
        echo "Service temporarily unavailable"
        return 1
    fi
    
    # Verify JSON structure
    if ! echo "${response}" | jq -e '.root.station[0].etd' >/dev/null 2>&1; then
        echo "[ERROR] Invalid or incomplete ETD data received"
        echo "Unable to retrieve schedule"
        return 1
    fi
    
    # Parse and format departure times
    departures=$(echo "${response}" | jq -r '.root.station[0].etd[] | 
        if .estimate[0].minutes == "Leaving" then
            "\(.destination): Leaving"
        else
            "\(.destination): \(.estimate[0].minutes) min"
        end' 2>/dev/null)
    
    if [ -z "${departures}" ]; then
        echo "[WARNING] No departure data available"
        echo "No trains currently scheduled"
        return 1
    fi
    
    echo "${departures}"
}

################################################################################
# Function: display_bart_information
# Description: Displays BART transit information using swiftDialog
################################################################################
display_bart_information() {
    local service_status
    local live_schedule
    local message_font
    local dialog_title
    local dialog_message
    local dialog_infobox
    
    # Fetch current BART data
    service_status=$(get_bart_service_status)
    live_schedule=$(get_live_departures)
    
    # Set font based on service status
    if [ -n "${service_status}" ]; then
        message_font="${MESSAGE_FONT_ALERT}"
    else
        message_font="${MESSAGE_FONT_NORMAL}"
        service_status="All systems operational"
    fi
    
    # Construct dialog elements
    dialog_title="BART - Live Transit Times From Civic Center"
    
    dialog_message="BART Current Status - Any delays will be posted here:\n${service_status}\n\n"
    dialog_message+="Civic Center Schedule:\n${live_schedule}"
    
    dialog_infobox="__Welcome to ${ORG_NAME}!__\n\n"
    dialog_infobox+="__${ORG_ADDRESS}__\n\n"
    dialog_infobox+="${ORG_PHONE}\n\n"
    dialog_infobox+="__Need Help?__\n${ORG_EMAIL}"
    
    # Display dialog
    echo "[INFO] Displaying BART information dialog..."
    
    ${DIALOG_BIN} \
        --title "${dialog_title}" \
        --titlefont "${TITLE_FONT}" \
        --message "${dialog_message}" \
        --messagefont "${message_font}" \
        --icon "${ICON_PATH}" \
        --iconsize 120 \
        --height 100% \
        --width 100% \
        --background "${WALLPAPER_DIR}${WALLPAPER_FILE}" \
        --infobox "${dialog_infobox}" \
        --timer "${DISPLAY_TIMER}" \
        --webcontent "${BART_WEB_URL}" \
        --button1text "Refresh"
    
    return $?
}

################################################################################
# Function: main
# Description: Main execution flow
################################################################################
main() {
    echo "════════════════════════════════════════════════════════════"
    echo "BART Transit Information Display - Starting"
    echo "Station: ${BART_STATION} (Civic Center)"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
    
    # Install dependencies
    echo "[STEP 1/3] Installing dependencies..."
    install_wallpaper || echo "[WARNING] Wallpaper installation skipped"
    
    if ! install_swift_dialog; then
        echo "[ERROR] Failed to install swiftDialog"
        exit 1
    fi
    
    # Verify dialog binary
    if [ ! -x "${DIALOG_BIN}" ]; then
        echo "[ERROR] swiftDialog binary not found or not executable"
        exit 1
    fi
    
    echo "[STEP 2/3] Verifying BART API connectivity..."
    if ! curl -s --connect-timeout 5 "${BART_BSA_URL}" >/dev/null; then
        echo "[WARNING] BART API may be unreachable"
    fi
    
    # Display BART information
    echo "[STEP 3/3] Launching display..."
    display_bart_information
    
    echo "════════════════════════════════════════════════════════════"
    echo "Session completed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
}

################################################################################
# Script Execution
################################################################################

# Execute main function
main "$@"




-----OG
#!/bin/bash

#parameters
BART_API_KEY="key goes here"


install_dialog () {
	
    updatedDialogVersion=2.5.3
	dialog_bin="/usr/local/bin/dialog"
	dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.3/dialog-2.5.3-4785.pkg"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"
    
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
    
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
	
	
	
		dialogIconDir="/Library/Application Support/SideIT/finishing.png"
		dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
		dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
		dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
		dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
	

}





#====================================
# Regular Alert
get_bart_status () {
	BART_API_KEY="ZAXL-PQDK-996T-DWEI"
	BSA_URL="https://api.bart.gov/api/bsa.aspx?cmd=bsa&key=${BART_API_KEY}&json=y"

	# Fetch service advisories
	bsa_response=$(curl -s "$BSA_URL")

	# Display the full response for troubleshooting
	echo "Full BART API Response:"
	echo "$bsa_response"

	sleep 2
	
	# Extract advisories text using sed for cdata-section
	echo "BART Service Advisories:"
	echo "$bsa_response" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p'
	bart_status=$(echo "$bsa_response" | sed -n 's/.*"description":{"#cdata-section":"\([^"]*\)"}.*/\1/p')
	
	sleep 3
	
	if [ -n "$bart_status" ]; then
	  msg_font="name=Arial-MT,size=18,colour=#FF0000"
	else
	  msg_font="name=Arial-MT,size=15"
	fi
	
	
}

get_station_schedule () {


echo "bart_api_countdown: "$bart_api_countdown

	# Deduct 1 from the countdown
let bart_api_countdown=$bart_api_countdown-1

# When countdown reaches 0, run the special command and reset the countdown
if (($bart_api_countdown == 0)); then
  echo "Running special command on loop $i"


# Replace with your BART API key
API_KEY="ZAXL-PQDK-996T-DWEI"

# Define the BART API URL for live departures from Civic Center station (CIVC)
API_URL="http://api.bart.gov/api/etd.aspx?cmd=etd&orig=CIVC&json=y&key=$API_KEY"

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
fi

	
}


bart_page () {

get_bart_status
get_station_schedule

dTitle="BART - Live Transit Times From Civic Center"
dMessage="Bart Current Status - Any delays will be posted here:\n
$bart_status \n\n

Civic Center Schedule: \n
**$live_schedule_times**"

timer=20 # 60 seconds * 10 min = 600
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
    #--button2text "$dButton2" \

)


}


###### Regular Alert DONE

install_dialog

bart_page
