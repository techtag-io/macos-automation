#!/bin/bash

################################################################################
# Caltrain Transit Information Display
# Description: Displays live Caltrain transit times and service alerts
#              for San Francisco station with AI-powered alert processing
################################################################################

set -euo pipefail

################################################################################
# Configuration Constants
################################################################################

# API Configuration
readonly CALTRAIN_API_KEY="key"
readonly GEMINI_API_KEY="key"
readonly BART_API_KEY="key"
readonly CALTRAIN_API_URL="http://api.511.org/transit/servicealerts?api_key=${CALTRAIN_API_KEY}&agency=CT"
readonly CALTRAIN_WEB_URL="https://www.caltrain.com/station/sanfrancisco"

# API Rate Limiting
readonly API_REFRESH_INTERVAL=3  # Refresh every 3 display cycles
API_COUNTDOWN=${API_REFRESH_INTERVAL}
LAST_API_PULL_TIME=""
CACHED_ALERTS=""

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
readonly MESSAGE_FONT_NORMAL="name=Arial-MT,size=18"
readonly MESSAGE_FONT_ALERT="name=Arial-MT,size=18,colour=#FF0000"

# Display Settings
readonly DISPLAY_TIMER=10  # seconds per display cycle
readonly DISPLAY_ITERATIONS=10  # number of times to show the display

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
        echo "[INFO] Wallpaper already installed"
        return 0
    fi
    
    if [ ! -f "${WALLPAPER_PKG}" ]; then
        echo "[WARNING] Wallpaper package not found at ${WALLPAPER_PKG}"
        return 1
    fi
    
    echo "[INFO] Installing wallpaper..."
    sudo /usr/sbin/installer -pkg "${WALLPAPER_PKG}" -target /
    
    if [ -f "${wallpaper_path}" ]; then
        echo "[SUCCESS] Wallpaper installed"
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
            echo "[INFO] swiftDialog is up to date"
            return 0
        else
            echo "[INFO] Updating swiftDialog to ${DIALOG_VERSION}"
        fi
    else
        echo "[INFO] Installing swiftDialog ${DIALOG_VERSION}"
    fi
    
    # Download swiftDialog
    echo "[INFO] Downloading swiftDialog..."
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
    
    sleep 5
    
    # Cleanup
    sudo rm -f "${temp_pkg_path}"
    
    # Verify installation
    installed_version=$(get_installed_dialog_version)
    if [ "${installed_version}" = "${DIALOG_VERSION}" ]; then
        echo "[SUCCESS] swiftDialog ${DIALOG_VERSION} installed"
        return 0
    else
        echo "[ERROR] Installation verification failed"
        return 1
    fi
}

################################################################################
# Function: process_alerts_with_ai
# Description: Uses Gemini AI to clean and format service alerts
# Arguments:
#   $1 - Raw alert text to process
# Returns: Formatted, cleaned alert text
################################################################################
process_alerts_with_ai() {
    local raw_alerts="$1"
    local cleaned_alerts
    local ai_prompt
    
    if [ -z "${raw_alerts}" ]; then
        echo ""
        return 0
    fi
    
    echo "[INFO] Processing alerts with AI..."
    
    # Construct AI prompt
    ai_prompt="Please clean up the following text and organize it into a bullet point list with each item separated by new lines, removing any extraneous information and only leave the list items in English. Make sure the items are separated in new lines in bullet point order and all non-English text is removed. Remove anything with local week day. Here's the text: ${raw_alerts}"
    
    # Process with Gemini CLI
    if command -v gemini-cli &> /dev/null; then
        cleaned_alerts=$(gemini-cli prompt "${ai_prompt}" --key "${GEMINI_API_KEY}" 2>/dev/null)
        
        if [ -n "${cleaned_alerts}" ]; then
            echo "[SUCCESS] Alerts processed by AI"
        else
            echo "[WARNING] AI processing returned empty result, using raw alerts"
            cleaned_alerts="${raw_alerts}"
        fi
    else
        echo "[WARNING] gemini-cli not found, using raw alerts"
        cleaned_alerts="${raw_alerts}"
    fi
    
    echo "${cleaned_alerts}"
}

################################################################################
# Function: fetch_caltrain_alerts
# Description: Fetches and processes current Caltrain service alerts
# Updates: CACHED_ALERTS, LAST_API_PULL_TIME, API_COUNTDOWN
################################################################################
fetch_caltrain_alerts() {
    local response
    
    # Decrement countdown
    ((API_COUNTDOWN--)) || true
    
    echo "[INFO] API countdown: ${API_COUNTDOWN} cycles remaining"
    
    # Check if it's time to fetch new data
    if [ "${API_COUNTDOWN}" -ne 0 ]; then
        echo "[INFO] Using cached alerts"
        return 0
    fi
    
    echo "[INFO] Fetching live Caltrain service alerts..."
    
    # Validate API key
    if [ -z "${CALTRAIN_API_KEY}" ]; then
        echo "[ERROR] Caltrain API key is missing"
        CACHED_ALERTS="Error: API key not configured"
        API_COUNTDOWN=${API_REFRESH_INTERVAL}
        return 1
    fi
    
    # Fetch alerts from API
    response=$(curl -s --connect-timeout 10 "${CALTRAIN_API_URL}")
    
    if [ -z "${response}" ]; then
        echo "[WARNING] Empty response from Caltrain API"
        CACHED_ALERTS="Unable to retrieve current alerts"
        API_COUNTDOWN=${API_REFRESH_INTERVAL}
        return 1
    fi
    
    # Process alerts with AI
    CACHED_ALERTS=$(process_alerts_with_ai "${response}")
    
    # Update metadata
    LAST_API_PULL_TIME=$(date +"%m-%d-%Y %H:%M:%S")
    API_COUNTDOWN=${API_REFRESH_INTERVAL}
    
    echo "[SUCCESS] Alerts updated at ${LAST_API_PULL_TIME}"
}

################################################################################
# Function: display_caltrain_information
# Description: Displays Caltrain transit information using swiftDialog
################################################################################
display_caltrain_information() {
    local message_font
    local dialog_title
    local dialog_message
    local dialog_infobox
    local countdown_label
    
    # Fetch/update alerts
    fetch_caltrain_alerts
    
    # Determine countdown label
    if [ "${API_COUNTDOWN}" -eq 0 ]; then
        countdown_label="running now"
    else
        countdown_label="${API_COUNTDOWN} cycles remaining"
    fi
    
    # Set font based on alert status
    if [ -n "${CACHED_ALERTS}" ] && [ "${CACHED_ALERTS}" != "No alerts at this time" ]; then
        message_font="${MESSAGE_FONT_ALERT}"
    else
        message_font="${MESSAGE_FONT_NORMAL}"
    fi
    
    # Construct dialog elements
    dialog_title="Caltrain - Live Transit Times From San Francisco"
    
    dialog_message="Next live status update in: ${countdown_label}"
    if [ -n "${LAST_API_PULL_TIME}" ]; then
        dialog_message+="\nLast live update: ${LAST_API_PULL_TIME}"
    fi
    dialog_message+="\n\nCaltrain - Any delays will be posted here:\n"
    
    if [ -n "${CACHED_ALERTS}" ]; then
        dialog_message+="${CACHED_ALERTS}"
    else
        dialog_message+="No alerts at this time"
    fi
    
    dialog_message+="\n\n\nSan Francisco Schedule"
    
    dialog_infobox="__Welcome to ${ORG_NAME}!__\n\n"
    dialog_infobox+="__${ORG_ADDRESS}__\n\n"
    dialog_infobox+="${ORG_PHONE}\n\n"
    dialog_infobox+="__Need Help?__\n${ORG_EMAIL}"
    
    # Display dialog
    echo "[INFO] Displaying Caltrain information (Timer: ${DISPLAY_TIMER}s)"
    
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
        --webcontent "${CALTRAIN_WEB_URL}" \
        --button1text "Refresh" 2>/dev/null || true
}

################################################################################
# Function: run_display_loop
# Description: Runs the display in a continuous loop
################################################################################
run_display_loop() {
    local iteration
    
    echo "[INFO] Starting display loop (${DISPLAY_ITERATIONS} iterations)"
    
    for iteration in $(seq 1 ${DISPLAY_ITERATIONS}); do
        echo "════════════════════════════════════════════════════════════"
        echo "Display iteration ${iteration}/${DISPLAY_ITERATIONS}"
        echo "════════════════════════════════════════════════════════════"
        
        display_caltrain_information
        
        # Brief pause between iterations (if not last iteration)
        if [ "${iteration}" -lt "${DISPLAY_ITERATIONS}" ]; then
            sleep 2
        fi
    done
}

################################################################################
# Function: main
# Description: Main execution flow
################################################################################
main() {
    echo "════════════════════════════════════════════════════════════"
    echo "Caltrain Transit Information Display - Starting"
    echo "Station: San Francisco"
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
    
    echo "[STEP 2/3] Verifying API connectivity..."
    if ! curl -s --connect-timeout 5 "${CALTRAIN_API_URL}" >/dev/null; then
        echo "[WARNING] Caltrain API may be unreachable"
    fi
    
    # Check for gemini-cli
    if ! command -v gemini-cli &> /dev/null; then
        echo "[WARNING] gemini-cli not found - AI processing will be skipped"
    fi
    
    # Run display loop
    echo "[STEP 3/3] Launching display loop..."
    run_display_loop
    
    echo "════════════════════════════════════════════════════════════"
    echo "Display loop completed: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
}

################################################################################
# Script Execution
################################################################################

# Execute main function
main "$@"



----OG 
#!/bin/bash

universal_parameters(){
	#APIs
	caltrain_api_key="key"
	gemini_key="key"
	BART_API_KEY="key"
	
	#setting limits
	caltrain_api_countdown=3
	
	#dialog
    updatedDialogVersion=2.5.3
	dialog_bin="/usr/local/bin/dialog"
	dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.3/dialog-2.5.3-4785.pkg"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"
    
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
	
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





#====================================
# Regular Alert
caltrain_status () {
	
	
	echo "caltrain_api_countdown: "$caltrain_api_countdown

	# Deduct 1 from the countdown
	let caltrain_api_countdown=$caltrain_api_countdown-1

	  # When countdown reaches 0, run the special command and reset the countdown
	  if (($caltrain_api_countdown == 0)); then
	    echo "Getting CalTrain data $i"
	   
	   
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
	  fi

	
	
	
	
	
	echo "Cleaned text"
	echo "$cleaned_up_text"


	if [ -n "$cleaned_up_text" ]; then
		#yes text
		msg_font="name=Arial-MT,size=18,colour=#FF0000"
	else
		#no text
		msg_font="name=Arial-MT,size=18"
	fi


	
}

caltrain_page () {
caltrain_status

if [[ $caltrain_api_countdown -eq 0 ]]; then
  api_label="running now"
else
  api_label="$caltrain_api_countdown left"
fi


sleep 2

dTitle="Caltrain - Live Transit Times From San Francisco"
dMessage="Next live status update in: $api_label. Last live update: $caltrain_api_pull_time \n\n
Caltrain - Any delays will be posted here:\n
**$cleaned_up_text** \n\n
\n\n


San Francisco Schedule"


timer=10 # 60 seconds * 10 min = 600
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
    #--button2text "$dButton2" \

)


}


###### Regular Alert DONE
universal_parameters

install_dialog

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2

caltrain_page

sleep 2
