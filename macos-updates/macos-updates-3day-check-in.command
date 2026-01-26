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
  	  checkinCountFile='/tmp/checkinCount.txt'

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




#====================================
# Regular Alert

regularAlert () {
	

	
dTitle="Side IT Alert: Critical Software Update Available!"
dMessage="You are getting this message because this device needs to be updated to macOS $macOSVersion.

Since this is a _**Critical Zero-Day macOS Update**_, you will continue to get these alerts every 30min to 40min until the upgrade is completed.

_**These alerts can only be stopped by updating to macOS $macOSVersion**_

For your convenience, you have the \"Install macOS Ventura\" application in the /Applications folder ready to be installed. Just click \"Update Now\" to launch the installer.

-**If no user action is taken in ten minutes, this alert will auto-dismiss and launch the installer for you.**_

Please make sure all your important data is in Google Drive before proceeding!!\n\n
Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Update Now"
#dButton2="Postpone"
timer=600 #60 seconds * 10 min = 600
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
		--iconsize 120 \
	    --button1text "$dButton1" \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--height 45% \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
        --timer "$timer"
        #--button2text "$dButton2" \
	
	)		
	
	
		


	#Button pressed Stuff
	returncode=$?


	case ${returncode} in
	    0)  echo "Pressed Button 1: update"
		sudo open "/Applications/Install macOS Ventura.app"

		
	
	        ;;

	    2)  echo "Pressed Button 2: Postpone"
	
		

	        ;;
		
	    *)  echo "Error: No Button Pressed. Launcing Alert and dismissing. exit code ${returncode}"
        sudo open "/Applications/Install macOS Ventura.app"
		
		
        

	        ;;
	esac
	
}

###### Regular Alert DONE


checkTimers () {
	#ppCountFile='/usr/local/postponeCount.txt'
	  #checkinCountFile='/usr/local/checkinCount.txt'
	  
	  
	  if [ -f "$checkinCountFile" ]; then
		  echo "Checkin file found, extracting data"
		  
		  echo "Pulling checkin count data..."
		  checkinCountPull=$( tail -n 1 $checkinCountFile)
		  echo $checkinCountPull pulled from file
		  #postPoneTimeCut=$(sed 's/.\{3\}$//' <<< "postponeStartTime")
		  
		  if [[ "$checkinCountPull" < 2 ]]; then
			  echo "Checkin less than 2 since alert launch, counting up and exiting..."
			  echo "Adding 1 to checkin count"
			  checkinCountPull=$(echo "$checkinCountPull" | sed 's/[^0-9]//g')
			  echo "checkinCountPull after convert: "$checkinCountPull
			  let checkinCountPull=$checkinCountPull+1
			  echo "Remaining checkins: "$checkinCountPull
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			  echo "Exiting Script..."
			  
		  else
			  echo "Checkin is 2, checking postpone amounts"
			  
			  
			  echo "Resetting checkin..."
			  let checkinCountPull=1
			  
			  echo "Removing checkinCountFile"
			  sudo rm -rf $checkinCountFile
			  
			  echo "Creating new checkinCountFile with updated checkin count"
			  echo $checkinCountPull >> $checkinCountFile
			  
			   echo "Launching alert..."
			  regularAlert
			  
		   fi
		   
		   
	   else
		    
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
