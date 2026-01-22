#!/bin/bash

installSwiftDialog () {
	
    wallpaperDir="/Library/Application Support/wallpaper/"
    wallpaperImg="desktopwallpaper.jpg"
    wallpaperPKGDir="/Library/Application Support/Jamf/Waiting Room/wallpaper.pkg"
    
    if [ -f "$wallpaperDir$wallpaperImg" ]; then
    echo "Wallpaper found, skipping install"
    else
    echo "Installing wallpaper"
    sudo /usr/sbin/installer -pkg "$wallpaperPKGDir" -target /
    fi
	
	
	
	
	dialog_bin="/usr/local/bin/dialog"
	dialog_download_url="https://github.com/bartreardon/swiftDialog/releases/download/v2.2.1/dialog-2.2.1-4591.pkg"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"

	if [ -f $dialog_bin ]; then
		echo "Dialog app found, skipping install..."
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





##Parameters
macOSVersion="$4" #13.4.1
dlmacOSName="$5" #Ventura


##Device info
currentOSVersion=$(sw_vers -productVersion)
macSerial=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')

#macOS InstallAssistant PKG - this will contain and exract Install macOS Ventura.app
macOSURL='https://swcdn.apple.com/content/downloads/36/06/042-01917-A_B57IOY75IU/oocuh8ap7y8l8vhu6ria5aqk7edd262orj/InstallAssistant.pkg'
macOSDir="/tmp/"
macOSPKG="InstallAssistant.pkg"

#Dialog
dialogIconDir="/Library/Application Support/SideIT/ATTIcon.png"
dialogBackGroundDir="/Library/Application Support/wallpaper/desktopwallpaper.jpg"
dialogSlackURL="https://app.slack.com/client/T0XD2CN2V/CNW9PA7NG"
dialogHDURL="https://sideinc.freshservice.com/support/catalog/items/131"
dialogTitleFont="name=Arial-MT,colour=#CE87C1,size=30"

#install Dialog
installSwiftDialog

#====================================
#Room selection Travis - P07V6RQCQ1

if [ "$macSerial" = "C02W81UYJ1GG" ]; then #iMac Print Station 1 - C02W81UYJ1GG
	echo "iMac Print Station 1"
	room="Print Station 1"

elif [ "$macSerial" = "C02X75SUJ1GG" ]; then #iMac Print Station 2 - C02X75SUJ1GG
	echo "iMac Print Station 2"
	room="Print Station 2"
	
elif [ "$macSerial" = "C07XP0N0JYVW" ]; then #Chalet
	echo "Chalet"
	room="Chalet"
	
elif [ "$macSerial" = "C07XR0UVJYVW" ]; then #Chateau
	echo "Chateau"
	room="Chateau"
	
elif [ "$macSerial" = "C07XQ3QDJYVW" ]; then #Embarcadero - C07XQ3QDJYVW
	echo "Embarcadero"
	room="Embarcadero"
	
elif [ "$macSerial" = "C07XK814JYVW" ]; then #Marina
	echo "Marina"
	room="Marina"
	
elif [ "$macSerial" = "C07XP0QPJYVW" ]; then #Penthouse
	echo "Penthouse"
	room="Penthouse"
	
elif [ "$macSerial" = "C07XQ3UGJYVW" ]; then #Richmond
	echo "Richmond"
	room="Richmond"
	
elif [ "$macSerial" = "C07XQ2LHJYVW" ]; then #Tower
	echo "Tower"
	room="Tower"
	
elif [ "$macSerial" = "C07XQ1L3JYVW" ]; then #Townhome
	echo "Townhome"
	room="Townhome"

else
	echo "Serial not found"
	room = "Unknown"
fi

	



#====================================


installAlert () {
	
dTitle="Installing macOS $macOSVersion... Please wait"
dMessage="macOS $macOSVersion is being installed.

This process could take up to 45 minutes.\n\n Once done, the device will restart on its own
at which point the update will be complete.

Contact helpdesk@side.com with any questions.

Thank you! \n
Side IT Helpdesk"
dIconDir="$dialogIconDir"
web="https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif"
timer=2700 #60*45=2700
caffeineTimer=3600 #60*60=3600 
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
__Room:__
$room\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Email__  
[helpdesk@side.com]($dialogHDURL)"


			caffeinate -i -s -d -t $caffeineTimer & updateNowAlert=$(${dialog_bin} \
			    --title "$dTitle" \
				--titlefont "$dialogTitleFont" \
			    --message "$dMessage" \
				--messagefont "name=Arial-MT,size=30" \
			    --icon "$dIconDir" \
				--iconsize 250 \
				--helpmessage "$dHelp" \
				--helptitle "TITLE" \
				--webcontent "$web" \
				--blurscreen \
			    --infobox "$dInfoBox" \
				--background "$dialogBackGroundDir" \
				--big \
				--timer "$timer"
	
			)
}




macOSInstall () {

 currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
  echo "Logged in user: $currentUser"
  
  adminPass="@!d3.@dm1n"
	#/Applications/Install\ macOS\ $dlmacOSName.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installAlert
	echo $adminPass | "/Applications/Install\ macOS\ $dlmacOSName.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "sideadmin" --stdinpass" & installAlert
	
    killall Dialog

}




###=================================
#Download and Alert

echo "Verifying macOS Download..."
	if [ -a /Applications/Install\ macOS\ $dlmacOSName.app ]; then
    echo "Install found, lauching alert"
    macOSInstall
    
    else
    echo "downloading macOS"
    fi

	echo Downloading $macOSVersion
	#downloading InstallAssistant.pkg for Ventura
	curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
	
	#install - extract "Install macOS Ventura.app"
	sudo /usr/sbin/installer -pkg "$macOSDir$macOSPKG" -target /
	
	sleep 5
	#Cleanup - remove InstallAssistant.pkg
	sudo rm -rf "$macOSDir$macOSPKG"
	
	#softwareupdate --fetch-full-installer --full-installer-version "$macOSVersion"
	sleep 2
	


	echo "Verifying macOS Download..."
	if [ -a /Applications/Install\ macOS\ $dlmacOSName.app ]; then
		echo "App found... launch alert"
		macOSInstall
		
		
		
	else
		echo "App not found... exiting"
	#	sudo jamf recon -room "macOS Update Fail"
		exit 
	fi
