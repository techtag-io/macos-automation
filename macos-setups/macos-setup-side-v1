#!/bin/sh

#This script is put together by Travis Green - latest update 09.06.2024
#This script uses swiftdialog for specific dialogs and user input - big thank you to Bart Reardon! Buy him a coffee here; https://buymeacoffee.com/bartreardon
#This script was created as an automated setup for Side Inc devices - code is not copywritten but it was specifically designed for the needs of Sice, Inc.
#How it works:
#This script will first set all parameters needed to pull specific data and download Swift Dialog
#Next it will check to ensure power is connected, if running on battery, it will throw a dialog until power is connected
#Once confirmed power is connected, it will ask for the computer user password which will be used to update macOS at the end
#It will then launch jamfhelper with specific images and trigger policies to download and instal: Chrome, Drive, Zoom, Slack, then set several settings including device name and enable file vault
#At the end it will download macOS (version specific to needs - put in parameters), install the update and reboot

# wait until the Self Service process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Self Service..."
	setupProcess=$( /usr/bin/pgrep "Self Service" )
	sleep 3
done

#Set Parameters
# Keep system and display awake for the duration of the script
caffeinate -dims &


#dialog specs
dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#5e095e,size=40" #og: CE87C1
updatedDialogVersion=2.5.1
dialog_bin="/usr/local/bin/dialog"
dialog_download_url="https://github.com/swiftDialog/swiftDialog/releases/download/v2.5.1/dialog-2.5.1-4775.pkg"
dialogDir='/usr/local/'
swiftDialogPKG="swiftDialog.pkg"


#device specs
macOSVersion="$4"
macOSName="$5"
currentOSVersion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

#Get logged in user for password and install
echo Getting Logged In User
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
uid=$(id -u "$currentUser")
echo "Logged in user: $currentUser"



installSwiftDialog () {

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


##Start setup
#install swift Dialog
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/initiatingSetup.png -fullScreenIcon & installSwiftDialog
killall jamfHelper


##let's make sure they are connected to power!

power_check () {
    
dTitle="Please Connect To A Power Source"
dMessage="Side's new device setup is about to start. 
This includes installing several application and a full macOS update if necessary.

**Please connect the computer to a power source to ensure the device does not shut off.**

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
web="https://i.pinimg.com/originals/59/df/95/59df95ecfb490ed3bab39a283ae7d8fa.gif"
timer=5
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
			--messagefont "name=Arial-MT,size=13" \
		    --icon "$dIconDir" \
			--iconsize 250 \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--webcontent "$web" \
		    --infobox "$dInfoBox" \
			--background "$dialogBackGroundDir" \
			--timer "$timer" \
            --blurscreen true
	
		)
		
		dialogInstallPID=$! # Capture the dialog process ID
}



check_power_source() {
    pmset -g batt | grep "AC Power" &> /dev/null
    echo $?
}

# Initial check for power source
if [[ $(check_power_source) -eq 0 ]]; then
    echo "The laptop is running on AC power."
else
    echo "The laptop is running on battery power."
fi

# Loop until the power source is AC Power
until [[ $(check_power_source) -eq 0 ]]; do
    power_check

done

echo "The laptop is now running on AC power."




### Get computer password for macOS update
check_password () {
	
passCheck=" "
passTitle="Attention: Computer Password Needed/Required"

until [ $passCheck == "PASSED" ];
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
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
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
			--messagefont "name=Arial-MT,size=13" \
		    --icon "$dIconDir" \
			--iconsize 120 \
		    --button1text "$dButton1" \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--textfield "Password",required,secure \
			--big \
			--infobox "$dInfoBox" \
			--background "$dBackDir" \
			--blurscreen true
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

check_password






### Finally, all set, let's really begin!

#chrome
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/chrome.png -fullScreenIcon & sudo jamf policy -event googlechrome

#drive
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/drive.png -fullScreenIcon & sudo jamf policy -event googledrive

#slack
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/slack.png -fullScreenIcon & sudo jamf policy -event slack

#zoom & set dock (first run)
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/zoom.png -fullScreenIcon & sudo jamf policy -event zoominfo; sudo jamf policy -event modifyDock

#settings > inSiderIntranet App
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/intranet.png -fullScreenIcon & sudo jamf policy -event inSiderIntranet




#settings > machine dock
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings1.png -fullScreenIcon & sudo jamf policy -event modifyDock 

#settings > user fill
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings2.png -fullScreenIcon & sudo jamf policy -event uploadUser


#break
sleep 3

#settings > machine name
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings3.png -fullScreenIcon & sudo jamf policy -event mbpname

#settings > filevault login alert
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/filevaultenable.png -fullScreenIcon & sudo jamf policy -event fvenable

/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/filevaultenable.png -fullScreenIcon & -sleep 5

#close self service before rebooting
killall Self\ Service



#alert to show download & softwareupdate --fetch-full-installer --full-installer-version $macOSVersion
installing_macOS_notification () {
    
dTitle="Installing macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is being installed.

This process could take a while.\n Once done, the device will restart on its own
at which point the update will be complete.

**PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWERSOURCE SO IT IS NOT INTERRUPTED!**

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
#OG: https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif
web="https://cdn.osxdaily.com/wp-content/uploads/2019/02/brooklyn-sceensaver-animated-pedrommcarrasco-github.gif"
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
			--messagefont "name=Arial-MT,size=13" \
		    --icon "$dIconDir" \
			--iconsize 250 \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--webcontent "$web" \
		    --infobox "$dInfoBox" \
			--background "$dialogBackGroundDir" \
			--timer "$timer" \
            --blurscreen true
	
		)
		
		dialogInstallPID=$! # Capture the dialog process ID
}



downloading_macOS_notification () {

    
dTitle="Downloading macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is being downloaded.

This process could take a while.\n Once done, the device will restart on its own
at which point the update will be complete.

**PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWERSOURCE SO IT IS NOT INTERRUPTED!**

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
#OG: https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif
web="https://cdn.osxdaily.com/wp-content/uploads/2019/02/brooklyn-sceensaver-animated-pedrommcarrasco-github.gif"
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
				--messagefont "name=Arial-MT,size=13" \
			    --icon "$dIconDir" \
				--iconsize 250 \
				--helpmessage "$dHelp" \
				--helptitle "TITLE" \
				--webcontent "$web" \
			    --infobox "$dInfoBox" \
				--background "$dialogBackGroundDir" \
				--timer "$timer" \
                --blurscreen true
	
			)
				
	    dialogPID=$! # Capture the dialog process ID
}


download_macOS() {
    softwareupdate --fetch-full-installer --full-installer-version $macOSVersion &
    
    # Capture the PID of the download process
    downloadPID=$!
	echo "Started download with PID $downloadPID"

    # Wait for the download to finish
    wait $downloadPID
}



# Start both the dialog and download simultaneously
downloading_macOS_notification & download_macOS

until ! pgrep -x -P $processPID > /dev/null; do
    echo "Process $processPID is still running..."
    sleep 5  # Check every 5 seconds
done
kill $dialogPID
killall Dialog






##install
install_macOS() {
	echo $userPass | /Applications/Install\ macOS\ $macOSName.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass --rebootdelay 30
    
    # Capture the PID of the download process
    installPID=$!
	echo "Started install with PID $downloadPID"

    # Wait for the download to finish
    wait $installPID
}



# Start both the dialog and download simultaneously
installing_macOS_notification & install_macOS

until ! pgrep -x -P $processPID > /dev/null; do
    echo "Process $processPID is still running..."
    sleep 5  # Check every 5 seconds
done
kill $dialogInstallPID
killall Dialog



# End caffeinate process - Goodbye!
killall caffeinate
