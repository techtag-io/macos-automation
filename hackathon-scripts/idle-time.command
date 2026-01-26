#!/bin/bash

################################################################################
# Print Station Idle Monitor
# Description: Monitors user activity and displays security agreement dialog
#              after period of inactivity on shared print stations
# Organization: Travis Green
################################################################################

set -euo pipefail

################################################################################
# Configuration Constants
################################################################################

# Idle timeout configuration (in seconds)
readonly IDLE_TIMEOUT_SECONDS=$((5 * 60))  # 5 minutes
readonly CHECK_INTERVAL=1                   # Check every second

# Dialog binary path
readonly DIALOG_BIN="/usr/local/bin/dialog"

# Asset directories
readonly DIALOG_ICON="/Library/Application Support/SideIT/ATTIcon.png"
readonly DIALOG_BACKGROUND="/Library/Application Support/wallpaper/desktopwallpaper.jpg"

# URLs
readonly SLACK_URL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
readonly HELPDESK_URL="https://sideinc.freshservice.com/support/catalog/items/131"

# Dialog styling
readonly TITLE_FONT="name=Arial-MT,colour=#CE87C1,size=30"
readonly MESSAGE_FONT="name=Arial-MT,size=30"

# System information
readonly MAC_SERIAL=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

################################################################################
# Function: get_idle_time
# Description: Retrieves current system idle time in seconds
# Returns: Integer representing seconds of idle time
################################################################################
get_idle_time() {
    local idle_time_ns
    local idle_time_seconds
    
    # Get idle time in nanoseconds from IOHIDSystem
    idle_time_ns=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF; exit}')
    
    # Convert nanoseconds to seconds
    idle_time_seconds=$((idle_time_ns / 1000000000))
    
    echo "${idle_time_seconds}"
}

################################################################################
# Function: monitor_idle_time
# Description: Continuously monitors system idle time and triggers lock dialog
#              when idle timeout threshold is reached
################################################################################
monitor_idle_time() {
    local current_idle_time
    
    echo "Starting idle time monitoring..."
    echo "Timeout threshold: ${IDLE_TIMEOUT_SECONDS} seconds"
    
    while true; do
        current_idle_time=$(get_idle_time)
        
        echo "[$(date '+%H:%M:%S')] Current idle time: ${current_idle_time}s"
        
        # Check if idle timeout has been reached
        if [ "${current_idle_time}" -ge "${IDLE_TIMEOUT_SECONDS}" ]; then
            echo "Idle timeout reached (${current_idle_time}s >= ${IDLE_TIMEOUT_SECONDS}s)"
            echo "Launching security agreement dialog..."
            return 0
        fi
        
        # Wait before next check
        sleep "${CHECK_INTERVAL}"
    done
}

################################################################################
# Function: display_security_dialog
# Description: Displays security agreement dialog for print station usage
# Returns: Exit code based on user interaction
################################################################################
display_security_dialog() {
    local dialog_title="Side, Inc Print Station"
    local dialog_message
    local dialog_infobox
    local dialog_response
    local return_code
    
    # Construct dialog message
    read -r -d '' dialog_message <<-'EOF' || true
Greetings! 
This print station is available for anyone to use. If you need to print something, you will be able to do so from this computer.

ATTENTION:
By clicking "I Agree", you agree that you are using this device at your own risk.
This device is not monitored but it is an unsecure station used by anyone who needs it.

Upon clicking "I Agree", all data on the hard drive is automatically deleted and Google Chrome is reset so that all logins are logged out.

After 5 minutes of inactivity, the computer will auto-lock.
Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you!

Side IT Helpdesk
EOF
    
    # Construct info box content
    dialog_infobox="__Side IT Helpdesk__\n\n__Print Station__\n\n__Device Serial__\n${MAC_SERIAL}\n\n__Email__\n[helpdesk@side.com](${HELPDESK_URL})"
    
    # Display dialog
    dialog_response=$(${DIALOG_BIN} \
        --title "${dialog_title}" \
        --titlefont "${TITLE_FONT}" \
        --message "${dialog_message}" \
        --messagefont "${MESSAGE_FONT}" \
        --icon "${DIALOG_ICON}" \
        --iconsize 250 \
        --big \
        --infobox "${dialog_infobox}" \
        --button1text "I Agree" \
        --background "${DIALOG_BACKGROUND}" \
        --blurscreen
    )
    
    return_code=$?
    
    # Handle user response
    case ${return_code} in
        0)
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] User accepted agreement"
            return 0
            ;;
        *)
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Dialog closed with code: ${return_code}"
            return 1
            ;;
    esac
}

################################################################################
# Function: reset_station
# Description: Performs cleanup operations after user agreement
# Note: Placeholder for actual cleanup implementation
################################################################################
reset_station() {
    echo "Initiating station reset..."
    
    # TODO: Implement actual cleanup operations:
    # - Clear browser data
    # - Remove user files
    # - Reset application states
    # - Log session information
    
    echo "Station reset complete"
}

################################################################################
# Function: main
# Description: Main execution flow
################################################################################
main() {
    echo "════════════════════════════════════════════════════════════"
    echo "Side Print Station Monitor - Starting"
    echo "Serial: ${MAC_SERIAL}"
    echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════"
    
    # Verify dialog binary exists
    if [ ! -f "${DIALOG_BIN}" ]; then
        echo "ERROR: Dialog binary not found at ${DIALOG_BIN}"
        exit 1
    fi
    
    # Main monitoring loop
    while true; do
        # Display initial security dialog
        if display_security_dialog; then
            # User agreed - start monitoring
            monitor_idle_time
            
            # Idle timeout reached - perform reset
            reset_station
        else
            # User dismissed dialog - wait and try again
            echo "Waiting 30 seconds before retry..."
            sleep 30
        fi
    done
}

################################################################################
# Script Execution
################################################################################

# Execute main function
main "$@"



-----OG
#as soon as the mouse or keyboard makes an input, timer resets

#!/bin/bash

#parameters
#dialog
dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
dialog_bin="/usr/local/bin/dialog"
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')


startToIdle () {

idleTime=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
echo $idleTime
let timeToLock=5*60
timeToLock=10



until [ $idleTime == $timeToLock ];
do
	
	#Get idle time
	idleTime=$(ioreg -c IOHIDSystem | awk '/HIDIdleTime/ {print $NF/1000000000; exit}')
	#echo "Time Pass1: "$idleTime
	
	#convert float into int string (1.000000 into 1)
	idleTime="${idleTime%%.*}"
	
	#convert string into int
	idleTime=$(echo "$idleTime" | sed 's/[^0-9]//g')
	
	
	echo "Time Pass2: "$idleTime
	#sleep for 1 second so that every check is 1 second
	sleep 1

	#After 5 mintues - be done
done

echo "5 Minutes no activity, launching lock alert"
launchLock

}




launchLock () {
	
dTitle="Side, Inc Print Station"
dMessage="Greetings! 

This print station is available for anyone to use. If you need to print something, you will be able to do so from this computer.
	
ATTENTION:
By clicking \"I Agree\", you agree that you are using this device at your own risk.
This device is not monitored but it is an unsecure station used by anyone who needs it.
	
Upon clicking \"I Agree\", all data on the hard drive is automatically deleted and Google Chrome is reset so that all logins are logged out.
	
After 5 minutes of inactivity, the computer will auto-lock.

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
dButton="I Agree"
dInfoBox="__Side IT Helpdesk__\n\n
__Print Station__\n\n
__Device Serial__
$macSerial\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"


			updateNowAlert=$(${dialog_bin} \
			    --title "$dTitle" \
				--titlefont "$dialogTitleFont" \
			    --message "$dMessage" \
				--messagefont "name=Arial-MT,size=30" \
			    --icon "$dIconDir" \
				--iconsize 250 \
				--helpmessage "$dHelp" \
				--big \
			    --infobox "$dInfoBox" \
				--button1text "$dButton" \
				--background "$dialogBackGroundDir" \
				--blurscreen
	
			)
				
				
				
				#Button pressed Stuff
				returncode=$?


				case ${returncode} in
				    0)  echo "Pressed Button 1: I Agree"
					#code to download
					startToIdle
					#code to delete all, etc
		
		
					exit 0
				        ;;

		
				    *)  echo "Something else happened. exit code ${returncode}"
					exit 0

				        ;;
				esac
	

}



launchLock
