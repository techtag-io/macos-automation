#!/bin/bash

installSwiftDialog () {
	
    updatedDialogVersion=2.3.2
	dialog_bin="/usr/local/bin/dialog"
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

checkmacOSInstaller () {
	
	#macOS InstallAssistant PKG - this will contain and exract Install macOS Ventura.app
	#macOSURL - 13.5.2 - updated 08.08.2023
	macOSURL='https://swcdn.apple.com/content/downloads/13/14/042-43677-A_H6GWAAJ2G9/6yl1pnz2f3m5sg2b4gpic7vz2i1s1n9n23/InstallAssistant.pkg'
	macOSDir="/tmp/"
	macOSPKG="InstallAssistant.pkg"
	
	#Check for Installer
	macOSInsDir="/Applications/Install macOS Ventura.app"

	if [ -a "$macOSInsDir" ]; then
		echo "Installer found, proceeding..."
	else
		echo "Installer not found, downloading"
	echo Downloading $macOSVersion
	
	#downloading InstallAssistant.pkg for Ventura
	curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
	
	#install - extract "Install macOS Ventura.app"
	/usr/sbin/installer -pkg "$macOSDir$macOSPKG" -target /
	
	sleep 5
	
	#Cleanup - remove InstallAssistant.pkg
	sudo rm -rf "$macOSDir$macOSPKG"
	
	#verifying install
	if [ -a "$macOSInsDir" ]; then
		echo "Installer downloaded successfully, proceeding...."
	else
		echo "Installer failed, submitting ticket and exiting script"
		sudo jamf recon -room "macOS Update Fail"
		exit 0
	fi #fi for installer check after download
		
    fi #fi for primary installer check

}


setParameters () {
	
	macOSVersion="$4" #13.5.2
	dlmacOSName="$5" #Ventura
	macOSVersion2="$6" #12.6.9
	
	#enddate="$7" #2023-06-01

	macOSVersion="13.5.2"
	dlmacOSName="Ventura"
	macOSVersion2="12.6.9"
	#enddate="$7" #2023-06-01

	echo macOSVersion $macOSVersion
	echo macOSVersion2 $macOSVersion2
	echo enddate $enddate
    
    
    #Postpone info
  	  ppCountFile='/usr/local/postponeCount.txt'
  	  checkinCountFile='/usr/local/checkinCount.txt'

	####################

	##Device info
	currentOSVersion=$(sw_vers -productVersion)
	macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

	###################
	
	#Checking macOS Version for compatibility
	osversion=$(sw_vers -productVersion)
	echo "Current OS Version: $osversion"


	echo "Checking macOS Version..."
	if [ $osversion == "$macOSVersion" ] || [ $osversion == "$macOSVersion2" ]; then
		echo "macOS is up to date with $osversion, running recon and exiting..."
		sudo rm -rf $ppCountFile
		sudo rm -rf $checkinCountFile
	
	    sudo jamf recon
		exit 0
	else
		echo "macOS $osversion NOT on $macOSVersion or $macOSVersion2, proceeding..."
	fi
	########## Check macOS Version DONE
	
	#Checking for macOS installer
	checkmacOSInstaller

	#swiftDialog Parameters
	installSwiftDialog

	dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
	dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
	dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
	dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
	dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"
	
	
	#====================================

	  #Get logged in user for password and install
	  echo Getting Logged In User
	  currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
	  uid=$(id -u "$currentUser")
	  echo "Logged in user: $currentUser"
	 

}


###### RUN INSTALL START

installingMacOS () {
#Checking for Dialog 
installSwiftDialog
	
	
	
dTitle="Preparing macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is preparing the update.

This process could take up to 45 minutes.\n Once done, the device will restart on its own
at which point the update will install. Once it is complete, you will be presented with the login screen.

**Note - You cannot exit the alert, but you are able to work while this part of the update is taking place.
The computer will automatically reboot once the update is ready to install.
IT COULD BE FASTER THAN 45 MINUTES, so please be ready for a reboot at any time!**

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
		    --infobox "$dInfoBox" \
			--background "$dialogBackGroundDir" \
			--timer "$timer" \
            --moveable
			#--blurscreen 
	
		)
}
#====================================



##### RUN INSTALL END


##### Password Check START

#====================================
#Password Check and Postpone Confirmation
passwordCheck () {
	
passCheck=" "

until [ $passCheck == "PASSED" ];
do
	

	#if password not entered yet
		if [ "$passCheck" != "FAILED" ]; then
dTitle="Computer Password Required"
userPasswordNeeded="Please type in your computer password."
dialogTitleFont="$dialogTitleFont"

		else #if password failed

dTitle="INCORRECT PASSWORD! TRY AGAIN..."
userPasswordNeeded="_***INCORRECT PASSWORD, TRY AGAIN...***_"
dialogTitleFont="name=Arial-MT,colour=#FF0000,size=30"
		fi


	####==============================
	#Dialog Parameters
dMessage="The macOS update is about to begin.

Apple requires the user to authenticate with the computer password to update macOS.

PLEASE NOTE THAT FOR THE UPDATE TO BE SUCCESSFUL, YOU NEED TO KEEP THE DEVICE:
1. TURNED ON
2. CONNECTED TO A POWERSOURCE
3. CONNECTED TO THE INTERNET

IF ANY OF THE ABOVE ARE MISSING THE UPDATE MAY BE INTERRUPTED, WHICH MAY CAUSE DISRUPTION.

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

###Actual Password Check
	
dscl . authonly "$currentUser" "$userPass" &> /dev/null; resultCode=$?
	if [ "$resultCode" -eq 0 ];then
    	echo "Password Check: PASSED"
		passCheck="PASSED"
    	# DO THE REST OF YOUR ACTIONS....
	
	
	
		#Run installer
		echo $userPass | /Applications/Install\ macOS\ Ventura.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installingMacOS
		killall Dialog

	else
    	# Prompt for User Password
    	echo "Password Check: WRONG PASSWORD"
    	#wrongUserPassword
		passCheck="FAILED"
	fi

done


}


##### Password Check End




#====================================
# Regular Alert

regularAlert () {
	
	if [[ "$ppCountPull" == 0 ]]; then
		echo "No postpones remain - time to update"
dTitle="Side IT Alert: macOS $macOSVersion Update."
dMessage="You are getting this message because your device needs to be updated to macOS $macOSVersion.

Click \"Update Now\" to launch the update now - please be aware that this is immediate and you will not be able to use the device until the update is complete.

If you do not click \"Update Now\", this alert will automaticaly dismiss and automatically launch the macOS update in 60 minutes.

**You can no longer stop or postpone the update.**

Please make sure all your important data is in Google Drive!!\n\n
Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Update Now"
timer=3600 #60 seconds * 60 min = 3600
		
		
	else
		echo $ppCountPull "remain - launching normal alert"
	
	
dTitle="Side IT Alert: macOS $macOSVersion Update. $ppCountPull Postpones Left!"
dMessage="You are getting this message because your device needs to be updated to macOS $macOSVersion.

You have the option to postpone for about 60 minutes at which point you will be alerted again.

You can postpone the update $ppCountPull more times before it is automatically installed, potentially causing disruption.

These alerts can only be stopped by updating to macOS $macOSVersion

For your convenience, you have the \"Install macOS Ventura\" application in the /Applications folder ready to be installed, or just click \"Update Now\" 
\n**Note that clicking \"Update Now\" will trigger the update immediately and you will not be able to use the device until the update is complete.**

Unless you dismiss this alert, it will automatically dismiss itself in 10 minutes at which point the postpone timer will start.

Please make sure all your important data is in Google Drive before proceeding!!\n\n
Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Update Now"
dButton2="Postpone"
timer=600 #60 seconds * 10 min = 600
	fi

dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Postpones Left:__
$ppCountPull\n\n   
__Device Serial__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"


if [[ "$ppCountPull" == 0 ]]; then

	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
	    --message "$dMessage" \
		--messagefont "name=Arial-MT,size=13" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--height 60% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
		--moveable \
        --timer "$timer"
	
	)		
else
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
		--height 60% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
		--moveable \
        --timer "$timer"
	
	)		
	
fi
	
		


	#Button pressed Stuff
	returncode=$?


	case ${returncode} in
	    0)  echo "Pressed Button 1: update"
		passwordCheck

		exit 0
	
	        ;;

	    2)  echo "Pressed Button 2: Postpone"
	
		exit 0

	        ;;
		
	    *)  echo "Error: No Button Pressed. exit code ${returncode}"
        
        if [[ "$ppCountPull" == 0 ]]; then
        echo "No postpones left, one hour passed, user ignored, launching update alert..."
        passwordCheck
        else
		exit 0
        fi

	        ;;
	esac
	
}

###### Regular Alert DONE


checkTimers () {
	#ppCountFile='/usr/local/postponeCount.txt'
	  #checkinCountFile='/usr/local/checkinCount.txt'
	  
	  
	  if [ -f "$ppCountFile" ]; then
		  echo "Postpone file found, extracting data"
		  
		  echo "Pulling checkin count data..."
		  checkinCountPull=$( tail -n 1 $checkinCountFile)
		  echo $checkinCountPull pulled from file
		  #postPoneTimeCut=$(sed 's/.\{3\}$//' <<< "postponeStartTime")
		  
		  if [[ "$checkinCountPull" != 4 ]]; then
			  echo "Checkin less than 4 since alert launch, counting up and exiting..."
			  echo "Adding 1 to checkin count"
			  checkinCountPull=$(echo "$checkinCountPull" | sed 's/[^0-9]//g')
			  echo "checkinCountPull after convert: "$checkinCountPull
			  let checkinCountPull=$checkinCountPull+1
			  echo "Remaining checkins: "$checkinCountPull
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			  echo "Exiting..."
			  exit 0
		  else
			  echo "Checkin is 4, checking postpone amounts"
			  
			  
			  echo "Restting checkin..."
			  checkinCountPull=1
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			  
			  ppCountPull=$( tail -n 1 $ppCountFile)
			  echo $ppCountPull pulled from file
			  #postPoneTimeCut=$(sed 's/.\{3\}$//' <<< "postponeStartTime")
			  
			  	if [[ "$ppCountPull" != 0 ]]; then
					  echo "Not 7 postpones yet, allowing more postpones, launching alert..."
					  ppCountPull=$(echo "$ppCountPull" | sed 's/[^0-9]//g')
					  echo "ppCountPull after convert: "$ppCountPull
				  	echo "Removing 1 to checkin count"
				  	let ppCountPull=$ppCountPull-1
				  	echo "Remaining postpones: "$ppCountPull
			  
				  	echo "Removing checkinCountFile"
				  	sudo rm -rf $ppCountFile
			  
				  	echo "Creating new checkinCountFile with updated checkin count"
				  	echo $ppCountPull >> $ppCountFile
				  
				  	echo "Launching alert..."
				  	regularAlert
				  
			   else
				 	 echo "This is the 7th postpone, set alert to force automated update"
				  	#do stuff
					regularAlert
				  
			   fi
		   fi
		   
		   
	   else
		  
		  echo "Fresh push, launching primary alert"
		  let ppCountPull=7
		  echo "Remaining postpones: "$ppCountPull
	  
		  echo "Removing checkinCountFile"
		  sudo rm -rf $ppCountFile
	  
		  echo "Creating new checkinCountFile with updated checkin count"
		  echo $ppCountPull >> $ppCountFile
		  
		  
		  echo "Fresh push, launching primary alert"
		  let checkinCountPull=1
		  echo "Total Checkins: "$checkinCountPull
	  
		  echo "Removing checkinCountFile"
		  sudo rm -rf $checkinCountFile
	  
		  echo "Creating new checkinCountFile with updated checkin count"
		  echo $checkinCountPull >> $checkinCountFile
		  
		  echo "Launching alert..."
		  regularAlert
	      fi
	  			

}


#### LETS BEGIN!

echo "Checking Parameters and settings..."
setParameters

echo "Checking timers"
checkTimers
