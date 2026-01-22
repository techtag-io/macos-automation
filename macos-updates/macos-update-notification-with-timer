#!/bin/bash

# ### Creation ###
# This script is put together by Travis Green for Side, Inc, last updated 06.2023
#
# ### Purpose ###
# The purpose of this script is to encourage, and ultimate force, users to update their macOS to the security standard - ie - latest stable build (13.4 as the time of this writing)
#
# ### Leverage ###
# This script takes advanatage of a third party script found on Github: swiftDialog - https://github.com/bartreardon/swiftDialog - by Bart Reardon - BIG THANK YOU, BART!
#####  swiftDialog is used for specific dialogs where jamfHelper won't cut it
#
#
# ### Mothod ###
# The following parameters are set for easy access in Jamf
# macOSVersion="$4" - use this for the LATEST version of macOS - if users are on older major versions, this version will be downloaded and installed on their machine
# dlmacOSName="$5" - use this for the macOS NAME (eg: Ventura), this is used as a wild card for calling "Install macOS $5.app"
# macOSVersion2="$6" - use this if there is a secondary supported OS version: ex - today we have 13.4 (Ventura) for the primary macOS, and 12.6.6 (Monterey) as a -1 major version supported by the company - all older versiona are not supported
# enddate="$7" - use this for the deadline: eg - if you want them to have the install done by June 15th, 2023, put the date 2023-06-15 : if the update is not completed by this date, $macOSVersion will be forcefully downloaded and installed
#
# The policy will target "macOS NOT up to date" smart group - it is designed to only include machines that are not on $macOSVersion and $macOSVersion2
# Excluded from the policy: All Desktops (minus MacPro), and "macOS Up To Date" since if they are up to date, there is nothing to update
#
# Once the policy parameters are put in place and the policy is enabled, the policy will run every 15-20 minutes
# 
# If the device is up to date, recon is run to upload the new info to Jamf and is automatically removed from the policy being triggered
# If macOS is not up to date:
# ------ How many days are left?
# --------- If the number of days is 2+
# ------------ Is the time between 11:30AM-12:00PM / 4:30PM-5:00PM - Run REGULAR ALERT
# ------------ If the time is not in the slots mentioned above, it exits the script
# --------- If the number of days is 1 or in the past
# ------------ Check for the POSTPONE file
# ---------------- If the postpone file is NOT found - run the POSTPONE ALERT - this will download "Install macOS $5.app" and then launch the alert giving users the option to postpone until 6-11PM that same day
# ==== If "Install macOS $5.app" fails to download, recon is run adding "macOS Failed" to "ROOM" attribute, which triggers an email sent to security@side.com to notify us of the failed download, then the script it exited to avoid conflict
# ---------------- If the postpone file is found - pull the date from the file
# --------------------- Is the date in the PAST? Run INSTALL MACOS function - this will launch a notification that will give the user 30 min to save their data, after 30 minutes, a second notification will launch that blocks the window and the install will occur
# --------------------- Is the date TODAY?
# --------------------------- Is the time PAST the postpone time? (Ex: user selected 7PM and it is now 9:30PM)
# ------------------------------------ YES - launch notification with 5 minute timer, after 5 minutes, a second notification will launch that blocks the window and the install will occur
# ------------------------------------ NO - Is the time PAST 4:30 PM?
# ------------------------------------------- NO - Exit script
# ------------------------------------------- YES - launch alert with timer counting down until postpone time (Ex: If it is 4:45 and the postpone is 9PM, 9-4 = 5, so the timer is 5 hours) - after 5 hours, a second notification will launch that blocks the window and the install will occur



#====================================
#Checking for swiftDialog and installing if not found

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
	

}


#====================================





#====================================
#====================================
#### Setting parameters

#Settings JAMF Parameters
macOSVersion="$4" #13.5.2
dlmacOSName="$5" #Ventura
macOSVersion2="$6" #12.6.8
enddate="$7" #2023-06-01


echo macOSVersion $macOSVersion
echo macOSVersion2 $macOSVersion2
echo enddate $enddate

####################

##Device info
currentOSVersion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

###################

##Get date to calculate days
#Delay Timer
#Get todays date in year-month-day
today=$(date +%Y-%m-%d)
#enddate="$6" - set above
echo " "
echo " "
echo "today: "$today
echo "enddate: "$enddate
#Calculate days left
#Convert date into integer for calculation
todayToInt=$(echo "$today" | sed 's/[^0-9]//g')
enddateToInt=$(echo "$enddate" | sed 's/[^0-9]//g')


##Pulling time - current time in Hour:Minute
currenttime=$(date +%H:%M)
echo "Current time: "$currenttime


##Setting Directories
postPoneTimeDir='/usr/local/macOSUpdatePostponed.txt'
userApprovedConfirDir='/usr/local/userApprovedConfirmation.txt'
todaysDateDir='/usr/local/todaysDate.txt'

#macOS InstallAssistant PKG - this will contain and exract Install macOS Ventura.app
#macOSURL - 13.4.1 - updated 06.21.2023
#macOSURL='https://swcdn.apple.com/content/downloads/36/06/042-01917-A_B57IOY75IU/oocuh8ap7y8l8vhu6ria5aqk7edd262orj/InstallAssistant.pkg'
#macOSURL - 13.5.2 - updated 08.08.2023
macOSURL='https://swcdn.apple.com/content/downloads/13/14/042-43677-A_H6GWAAJ2G9/6yl1pnz2f3m5sg2b4gpic7vz2i1s1n9n23/InstallAssistant.pkg'
macOSDir="/usr/local/"
macOSPKG="InstallAssistant.pkg"

#swiftDialog Parameters
installSwiftDialog

updatedDialogVersion=2.3.2
dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"


#postpone items
#This is the fail safe in case the user postpones 
#and then doesnt leave the computer on for the update
postponeInterrupted="NULL"

############### End Parameters DONE
#====================================
#====================================










#====================================
#====================================
#CHECK Silicon Type

if [[ `uname -m` == 'arm64' ]]; then
  echo "Sicilone: M1"
  siliconType="M1"
  
  #Get logged in user for password and install
  echo Getting Logged In User
  currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
  uid=$(id -u "$currentUser")
  echo "Logged in user: $currentUser"
  
  
else
	echo "Silicone: Intel"
	siliconType="intel"
fi

################ CHECK Silicon DONE
#====================================
#====================================










#====================================# ## #====================================#
# ----- Alerts section


#====================================
# Regular Alert

regularAlert () {
	
   
	###################################
	###################################
	# Get current time in 24 hour (5PM would be 17:00)

	#currenttime=$(date +%H:%M)
	#echo "Current time: $currenttime"
   
	#modify time to start in 24 hour (5PM would be 17:00)
	startTimeA="11:35"
   
	#modify time to end in 24 hour(5PM would be 17:00)
	endTimeA="12:00"
   
	#modify time to start in 24 hour (5PM would be 17:00)
	startTimeB="16:35"
   
	#modify time to end in 24 hour(5PM would be 17:00)
	endTimeB="17:00"

	#Get Time End
	###################################
	###################################

	##########################################
	#If current time > User Selected Time

	
   
	if [[ "$currenttime" > "$startTimeA" ]] && [[ "$currenttime" < "$endTimeA" ]] || [[ "$currenttime" > "$startTimeB" ]] && [[ "$currenttime" < "$endTimeB" ]]; then
	  
		echo "In time zone... proceeding"

       
	else
		echo "Not time yet, exiting...."
		exit 0
	fi
       
	############# Get current time DONE
	#====================================
	
	
dTitle="Side IT Alert: You have $daysLeft days to install macOS $macOSVersion"
dMessage="You are getting this message because your device needs to be updated to either macOS $macOSVersion or macOS $macOSVersion2

You have until $enddate ($daysLeft days left), to update macOS before it is automatically installed for you, which may cause disruption.

If you would rather have $macOSVersion2 installed, you NEED to get it installed before $enddate or it will be overwritten with $macOSVersion

If it is not currently available, you may need to restart your computer at which point it will become available.

NOTE: Updates could be very large and could take up to an hour to install. The download time is dependent on your internet speed.

[Click here for the How-To Slides!](https://docs.google.com/presentation/d/1tsjCIHEZRb94YqHq0kwR1iQ03XseTDNIh6_Iy5umw7M/edit?usp=sharing)

Please make sure all your important data is in Google Drive before proceeding!!\n\n
Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Update Now"
dButton2="Dismiss"
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Update By:__
$enddate ($daysLeft days left)\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"
timer=600 #60 seconds * 10 min = 600



	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
	    --message "$dMessage" \
		--messagefont "name=Arial-MT,size=13" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
	    --button2text "$dButton2" \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--big \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
		--moveable \
        --timer "$timer"
	
	)		
		


	#Button pressed Stuff
	returncode=$?


	case ${returncode} in
	    0)  echo "Pressed Button 1: update"
		open -b com.apple.systempreferences /System/Library/PreferencePanes/SoftwareUpdate.prefPane

		exit 0
	
	        ;;

	    2)  echo "Pressed Button 2: dismiss"
	
		exit 0

	        ;;
		
	    *)  echo "Error: No Button Pressed. exit code ${returncode}"
		exit 0

	        ;;
	esac
	
}

###### Regular Alert DONE
#====================================
#====================================









#====================================
#====================================
#######################################


installingMacOS () {
#Checking for Dialog 
installSwiftDialog
	
	
	
dTitle="Installing macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is being installed.

This process could take up to 45 minutes.\n Once done, the device will restart on its own
at which point the update will be complete.

PLEASE MAKE SURE THE DEVICE IS CONNECTED TO A POWERSOURCE SO IT IS NOT INTERRUPTED!

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
web="https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif"
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
			--blurscreen \
		    --infobox "$dInfoBox" \
			--background "$dialogBackGroundDir" \
			--timer "$timer"
	
		)
}
#====================================
#====================================








#====================================
#====================================
# Run macOS Installer Function

RunmacOSUpdate () {
	#Checking for Dialog 
	installSwiftDialog


postPoneTimePullForAlert=$( tail -n 1 $postPoneTimeDir )
echo $postPoneTimePullForAlert pulled from file
postPoneTimeCutForAlert=$(sed 's/.\{3\}$//' <<< "$postPoneTimePullForAlert")


	


#add 60 minutes to countdownTimer for machine to stay awake
let caffeineTimer=$countdownTimer*3600
echo "Caffeine Timer: "$caffeineTimer

	#######################################
	#update now dialog
	if [[ "$postPoneTimeCutForAlert" = "18" ]]; then
		dialogTimeConverted="6 PM Tonight"
	
	elif [[ "$postPoneTimeCutForAlert" = "19" ]]; then
		dialogTimeConverted="7 PM Tonight"
	
	elif [[ "$postPoneTimeCutForAlert" = "20" ]]; then
		dialogTimeConverted="8 PM Tonight"
	
	elif [[ "$postPoneTimeCutForAlert" = "21" ]]; then
		dialogTimeConverted="9 PM Tonight"
	
	elif [[ "$postPoneTimeCutForAlert" = "22" ]]; then
		dialogTimeConverted="10 PM Tonight"
	
	elif [[ "$postPoneTimeCutForAlert" = "23" ]]; then
		dialogTimeConverted="11 PM Tonight"
	
	else
		echo "time not found"
	fi

if [[ "$currenttime" > "$postPoneTimePull" ]]; then
echo "Postpone time passed, running..."
dialogTimeConverted="5 minutes from now"
let countdownTimer=5*60
fi


if [ "$postponeInterrupted" = "Yes" ]; then
	dialogTimeConverted="30 minutes from now"
	let countdownTimer=30*60
else
	echo "Postpone not interrupted"
fi

dTitle="Side IT Alert! macOS Update starting soon!"
dMessage="macOS $macOSVersion update is scheduled to begin in $dialogTimeConverted!.\n

Please make sure all your data is saved by the time the timer is up.\n\n

You have until $dialogTimeConverted before the update starts automatically,\nat which point, you will no longer be able to use the device until the update is complete. 

You are free to update at any point before the timer is up.
If you are ready to update now, click \"Update Now\",\n which will start the update IMMEDIATELY.

THIS PROCESS CAN NO LONGER BE STOPPED, DELAYED OR POSTPONED.\n
A RESTART WILL BE TAKING PLACE ONCE THE UPDATE IS COMPLETE.

Contact helpdesk@side.com or #it-support in Slack with any questions.
Thank you! \n
Side IT Helpdesk"
dButton1="Update Now"
dTimer=$countdownTimer #pulling from calculation
dIconDir="$dialogIconDir"
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




		caffeinate -i -s -d -t $caffeineTimer & ${dialog_bin} \
			--title "$dTitle" \
			--titlefont "$dialogTitleFont" \
			--message "$dMessage" \
			--messagefont "name=Arial-MT,size=13" \
			--icon "$dIconDir" \
			--iconsize 150 \
			--button1text "$dButton1" \
			--timer "$dTimer" \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--big \
			--infobox "$dInfoBox" \
			--background "$dialogBackGroundDir" \
			--moveable #moveable
	

	#If Silicone is M1, we need the creds
	
if [ "$siliconType" == "M1" ]; then
	
	userPassDir=$userApprovedConfirDir
	#look for creds file and pull creds
	if [[ -f $userPassDir ]]; then
	echo "Pass file found... pulling pass"
	
	
	userPass=$( tail -n 1 $userPassDir )
	#hiding password from text - uncomment below to show password
	#echo "$userPass pulled from file"
	
	#code for creds
	##GET PASSWORD FROM TEXTFILE / USER FROM ABOVE
echo $userPass | /Applications/Install\ macOS\ Ventura.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installingMacOS
killall Dialog
	else
	echo "Password file not found, exiting to avoid conflict"
	exit 0
	fi
	
	
else #else if Silicon is intel, we don't need creds
	echo "intel - no creds needed - running erase-install to update"

/Applications/Install\ macOS\ Ventura.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installingMacOS
killall Dialog
fi


}

# Run macOS Installer Function DONE
#====================================
#====================================










#====================================
#====================================
#Password Check and Postpone Confirmation
postponeConfirmation () {
	
passCheck=" "

until [ $passCheck == "PASSED" ];
do
	

	#Check for Intel vs M1
if [ "$siliconType" == "M1" ]; then
echo "apple silicon"

	#if password not entered yet
		if [ "$passCheck" != "FAILED" ]; then
dTitle="The update will happen AFTER $postPoneWindowSelected"
userPasswordNeeded="Apple requires the user to authenticate with the computer password to update macOS
Please confirm your computer password to confirm the update schedule."
dialogTitleFont="$dialogTitleFont"

		else #if password failed

dTitle="INCORRECT PASSWORD! TRY AGAIN..."
userPasswordNeeded="Apple requires the user to authenticate with the computer password to update macOS
Please confirm your computer password to confirm the update schedule.\n\n_***INCORRECT PASSWORD, TRY AGAIN...***_"
dialogTitleFont="name=Arial-MT,colour=#FF0000,size=30"
		fi
else
echo "intel"
dTitle="The update will happen AFTER $postPoneWindowSelected"
userPasswordNeeded=" "
passCheck="PASSED"
fi



	####==============================
	#Dialog Parameters
dMessage="Your macOS Update to macOS $macOSVersion is set to take place after $postPoneWindowSelected.
You are still able to install the update yourself before $postPoneWindowSelected by going to /Applications/ and running
\"Install macOS $dlmacOSName\"

PLEASE NOTE THAT FOR THE UPDATE TO BE SUCCESSFUL, YOU NEED TO KEEP THE DEVICE:
1. TURNED ON
2. CONNECTED TO A POWERSOURCE
3. CONNECTED TO THE INTERNET

IF ANY OF THE ABOVE ARE MISSING THE UPDATE WILL BEGIN THE NEXT TIME
THE DEVICE IS ONLINE, WHICH MAY CAUSE DISRUPTION.

$userPasswordNeeded


Contact helpdesk@side.com or #it-support in Slack with any questions."
dButton1="I Understand"
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

	#Check for Intel vs M1
	if [ "$siliconType" == "M1" ]; then
		echo "apple silicon"
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
	
	
	
	else
		echo "intel"
		postPoneConfirm=$(${dialog_bin} \
		    --title "$dTitle" \
			--titlefont "$dialogTitleFont" \
		    --message "$dMessage" \
			--messagefont "name=Arial-MT,size=13" \
		    --icon "$dIconDir" \
			--iconsize 120 \
		    --button1text "$dButton1" \
			--timer "$dTimer" \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--big \
			--background "$dBackDir" \
			--infobox "$dInfoBox" 
		
		)
	fi

#uncomment below to show password in plain text
#echo "Confirm: "$postPoneConfirm
#echo ${postPoneConfirm:11}
userPass=${postPoneConfirm:11}

#use echo below to confirm - not printing for security
#echo userPass is $userPass

###Actual Password Check
if [ "$siliconType" == "M1" ]; then #If Apple Silicone, verify password
	
dscl . authonly "$currentUser" "$userPass" &> /dev/null; resultCode=$?
	if [ "$resultCode" -eq 0 ];then
    	echo "Password Check: PASSED"
		passCheck="PASSED"
    	# DO THE REST OF YOUR ACTIONS....
	
		#Put password in temp file for update
		echo $userPass > $userApprovedConfirDir

	else
    	# Prompt for User Password
    	echo "Password Check: WRONG PASSWORD"
    	#wrongUserPassword
		passCheck="FAILED"
	fi
else #if intel - skip verify
	passCheck="PASSED"
fi

done


}

###----------------------- POSTPONE CONFIRM + PASSWORD FUNCTION END

PostPoneIT () {
	
echo Downloading $macOSVersion
#softwareupdate --fetch-full-installer --full-installer-version $macOSVersion
#downloading InstallAssistant.pkg for Ventura
curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
#install - extract "Install macOS Ventura.app"
/usr/sbin/installer -pkg "$macOSDir$macOSPKG" -target /
sleep 5
#Cleanup - remove InstallAssistant.pkg
sudo rm -rf "$macOSDir$macOSPKG"


echo "Verifying macOS Download..."
if [ -a /Applications/Install\ macOS\ $dlmacOSName.app ]; then
	echo "App found... launch alert"
else
	echo "App not found... exiting"
	sudo jamf recon -room "macOS Update Fail"
	exit 0
fi

#######################################
#Postpone dialog - select a time
#Dialog Postpone Select Pre-Req
dTitle="Side IT Alert! Immediate User Action Required!"
dMessage="Your device needs to be upgraded to macOS $macOSVersion.\n
Click \"Install NOW\" to install the update IMMEDIATELY \n\n!THIS WILL LAUNCH THE INSTALLER AND REBOOT AUTOMATICALLY NOW!
\n
ATTENTION!\n
You can postpone ONE TIME! If you postpone, the update will AFTER the time you select below.
Once selected, the postpone time cannot be changed or cancelled.

You have ten minutes to select a time. If you do not take any action, the postpone will default to \"After 6 PM Tonight\"

Once postponed, if you forget to leave your device turned on and/or connected
for the update to happen, THE UPDATE WILL TAKE PLACE AS SOON AS THE DEVICE COMES BACK ONLINE,
potentially causing disruption!

Contact helpdesk@side.com or #it-support in Slack with any questions."
dButton1="Postpone until time selected"
dButton2="Install Now"
dTimer=600 #turn into 600 for ten minutes
dPostponeTitle="Postpone until"
dPostPoneSelect="After 6 PM Tonight,After 7 PM Tonight,After 8 PM Tonight,After 9 PM Tonight,After 10 PM Tonight,After 11 PM Tonight"
dSelectDefault="After 6 PM Tonight"
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



userTimeSelection=$(${dialog_bin} \
    --title "$dTitle" \
	--titlefont "$dialogTitleFont" \
    --message "$dMessage" \
	--messagefont "name=Arial-MT,size=13" \
    --icon "$dIconDir" \
	--iconsize 150 \
    --button1text "$dButton1" \
    --button2text "$dButton2" \
	--selecttitle "$dPostponeTitle" \
	--selectvalues "$dPostPoneSelect" \
	--selectdefault "$dSelectDefault" \
	--timer "$dTimer" \
	--helpmessage "$dHelp" \
	--helptitle "TITLE" \
	--big \
	--background "$dialogBackGroundDir" \
	--infobox "$dInfoBox" 

)
		
		


#Button pressed Stuff
returncode=$?


case ${returncode} in
    0)  echo "Pressed Button 1"
	#Select index:
	#0 = 6-7
	#1 = 7-8
	#2 = 8-9
	#3 = 9-10
	#4 = 10-11
	#5 = 11-12
	echo "userTimeSelection: "$userTimeSelection
	#postponeWindow=$(echo grep $userTimeSelection "SelectedIndex" | awk -F ": " '{print $NF}')
	postponeWindowIndex=$(echo grep $userTimeSelection | awk -F ": " '{print $NF}')
	echo "Time Window: "$postponeWindowIndex
	
	if [ "$postponeWindowIndex" == "\"0\"" ]; then
		echo "Time Selected 6PM"
		postPoneWindowSelected="6 PM"
		startTimeChosen="18:00"
		
	elif [ "$postponeWindowIndex" == "\"1\"" ]; then
		echo "Time Selected 7PM"
		postPoneWindowSelected="7 PM"
		startTimeChosen="19:00"
		
	elif [ "$postponeWindowIndex" == "\"2\"" ]; then
		echo "Time Selected 8PM"
		postPoneWindowSelected="8 PM"
		startTimeChosen="20:00"
		
	elif [ "$postponeWindowIndex" == "\"3\"" ]; then
		echo "Time Selected 9PM"
		postPoneWindowSelected="9 PM"
		startTimeChosen="21:00"
		
	elif [ "$postponeWindowIndex" == "\"4\"" ]; then
		echo "Time Selected 10PM"
		postPoneWindowSelected="10 PM"
		startTimeChosen="22:00"
		
	elif [ "$postponeWindowIndex" == "\"5\"" ]; then
		echo "Time Selected 11PM"
		postPoneWindowSelected="11 PM"
		startTimeChosen="23:00"
		
	fi
	
	#Crete postpone files with timestame
	#User Chosen Timer in macOSUpdatePostponed.txt
	echo $startTimeChosen > $postPoneTimeDir
	#Todays date in todaysDate.txt for confirmation
	echo $todayToInt > $todaysDateDir
	
	
	#Run postpone confirm window
	postponeConfirmation
	

        ;;

    2)  echo "Pressed Button 2"
	#Install NOW pressed
	echo "Creating backup files in case user does not install"
	#User Chosen Timer in macOSUpdatePostponed.txt
	echo "18:00" > $postPoneTimeDir
	#Todays date in todaysDate.txt for confirmation
	echo $todayToInt > $todaysDateDir
	#Launch App
	open /Appliations/Install\ macOS\ $dlmacOSName.app
        ;;
		
    *)  echo "Something else happened. exit code ${returncode}"
	#Timer is up - default postpone selected - 6-7PM
	echo default selected
	echo "Time Selected 6PM"
	postPoneWindowSelected="6 PM"
	startTimeChosen="18:00"
    
    #Crete postpone files with timestame
	#User Chosen Timer in macOSUpdatePostponed.txt
	echo $startTimeChosen > $postPoneTimeDir
	#Todays date in todaysDate.txt for confirmation
	echo $todayToInt > $todaysDateDir
	postponeConfirmation
        ## Catch all processing
        ;;
esac




	
} #### 24Hr Notice closing braket

######### 24Hr Notice Function DONE
###################################
###################################




###################################
###################################
###################################
#check OS version

osversion=$(sw_vers -productVersion)
echo "Current OS Version: $osversion"


echo "Checking macOS Version..."
if [ $osversion == "$macOSVersion" ] || [ $osversion == "$macOSVersion2" ]; then
	echo "macOS is up to date with $osversion, running recon and exiting..."
	
	sudo rm -Rf $postPoneTimeDir
	sudo rm -Rf $userApprovedConfirDir
	sudo rm -Rf $todaysDateDir
    sudo jamf recon
	exit 0
else
	echo "macOS $osversion NOT on $macOSVersion or $macOSVersion2, proceeding with time check for alert..."
fi
########## Check macOS Version DONE
###################################
###################################


###################################
###################################
# Check for postpone file and if available, pull time
# check for todaysDate.txt
# Check for postpone file and if available, pull time
if [ -f $todaysDateDir ]; then
		echo "todaysDate.txt file found... pulling date"
		
		postPoneDatePull=$( tail -n 1 $todaysDateDir )
		echo $postPoneDatePull pulled from file
		
		let runToday=$postPoneDatePull-$todayToInt
        echo "postPineDatePull: "$postPoneDatePull
        echo "todayToInt: "$todayToInt
        echo "runToday Result: "$runToday
		
		##################################################
		#Check date - was the date postponed today?
		if [[ "$runToday" == 0 ]]; then
			echo "Date is today, check time..."
			
			
			##############################################
			#Does postpone time exist?
			if [ -f $postPoneTimeDir ]; then
				
				echo "Postpone file found... pulling time"
				postPoneTimePull=$( tail -n 1 $postPoneTimeDir )
				echo $postPoneTimePull pulled from file
                echo "Current Time: "$currenttime
                postPoneTimeCut=$(sed 's/.\{3\}$//' <<< "$postPoneTimePull")
       
				
				
				
				
				##Calculcate time remaining
				#pull current time in hours
				currenttimeHours=$(date +%H)
				#convert it to integer
				currenttimeHours=$(echo "$currenttimeHours" | sed 's/[^0-9]//g')
				echo Current Hour is $currenttime

				#deduct postpone time from current time to have timer
				let countDifference=$postPoneTimeCut-$currenttimeHours
				#conver timer hours into seconds
				let countdownTimer=$countDifference*60*60

				echo "Current Time:" $currenttimeHours
				echo "Postpone Time Cut:" $postPoneTimeCut
				echo "Time Difference:" $countDifference
				echo "Countdown time in seconds:" $countdownTimer
				
				
				
				
				
				
				
				#########################################
				#is now time >= postpone select time - run, else exit
				#if [[ "$currenttime" = "$postPoneTimePull" ]] || [[ "$currenttime" > "$postPoneTimePull" ]]; then
				
               if [[ "$currenttime" > "16:30" ]]; then
				echo "Time is here, running update..."
				RunmacOSUpdate
						
                       
				else #Time not here
				echo "Time not here, exit script"
				exit 0
				fi
				####### IF TIME >= NOW DONE
				#########################################
				
			
	
			
			else
				echo "there has been an error with the date, exiting..."
				exit 0
			fi ## Post Pone Time File Found DONE
			##############################################
		
   	elif [[ "$runToday" < 0 ]]; then
		echo "Date is in the past, running update"
		postponeInterrupted="Yes"
		RunmacOSUpdate
	else
		echo "Today file not found..., exiting to avoid conflict"
		exit 0
	fi ## exit check for today file DONE
	##################################################
else
	echo "postpone file not found, continuing with script"
fi ## check for Today file DONE


 

 
#====================================
# Getting Date Timer


let daysLeft=$enddateToInt-$todayToInt

echo "Days left before force download: " $daysLeft

#if today is due date
if [[ "$today" = "$enddate" ]] || [[ "$today" > "$enddate" ]]; then
    echo $enddate is TODAY or PAST
  
	echo "Running PostPoneIT Alert"
    PostPoneIT

#else if due date is in the future
else 
	echo $enddate is not here yet, proceeding with normal alert
	regularAlert
fi
########## Getting Date Timer DONE
#====================================
