#!/bin/bash

#Show alert - clicking proceed will start the download of macOS, once done you will get another alert to install macOS - at this point the screen will be blocked so that the install is not interrupted

#alert1 - click proceed to download
#alert2 - show status bar while downloading
## confirm download
#alert3 - click install to install / dismiss to install later
##only if install
#alert 4 - block screen and install




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
macOSURL='https://swcdn.apple.com/content/downloads/63/49/032-84910-A_3SSTBN1HDA/h89vitwfbzt54jcbwpfwkmrn12smedicny/InstallAssistant.pkg'
macOSDir="/usr/local/"
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




#====================================


installAlert () {
	
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
caffeineTimer=3600 #60*60=3600 
dInfoBox="__macOS Version__  
$currentOSVersion\n\n   
__Device Serial__
$macSerial\n\n
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
				--timer "$timer"
	
			)
}


appleSiliconInstall () {

	echo "apple silicon"
	passCheck=" "

	until [ $passCheck == "PASSED" ];
	do
	
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

	
			echo "apple silicon"
			postPoneConfirm=$(${dialog_bin} \
			    --title "$dTitle" \
				--titlefont "$dialogTitleFont" \
			    --message "$dMessage" \
				--messagefont "name=Arial-MT,size=30" \
			    --icon "$dIconDir" \
				--iconsize 120 \
			    --button1text "$dButton1" \
				--helpmessage "$dHelp" \
				--helptitle "TITLE" \
				--textfield "Password",required,secure \
				--big \
				--infobox "$dInfoBox" \
				--background "$dBackDir" 
				#--blurscreen true
			)
	
	
	
		
	

	echo "Confirm: "$postPoneConfirm
	#echo ${postPoneConfirm:11}
	userPass=${postPoneConfirm:11}

	#use echo below to confirm - not printing for security
	#echo userPass is $userPass
	
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


	done



	echo $userPass | /Applications/Install\ macOS\ Ventura.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installAlert
	killall Dialog
}

intelInstall () {

	/Applications/Install\ macOS\ $dlmacOSName.app/Contents/Resources/startosinstall --agreetolicense --nointeraction --user "$currentUser" --stdinpass & installAlert
	killall Dialog

}





#====================================
#CHECK Silicon Type

siliconCheck () {
if [[ `uname -m` == 'arm64' ]]; then
  echo "Sicilone: M1"
  siliconType="M1"
  
  #Get logged in user for password and install
  echo Getting Logged In User
  currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
  echo "Logged in user: $currentUser"
  
  appleSiliconInstall
  
  
else
	echo "Silicone: Intel"
	siliconType="intel"
	intelInstall
	
	
fi
}

################ CHECK Silicon DONE
#====================================
#====================================


#====================================
## Ask to install

askToInstall () {

dTitle="Side IT Alert: macOS Install"
dMessage="macOS $macOSVersion has successfully downloaded and is ready to be installed.
	
PLEASE NOTE - Clicking \"Install\" will automatically block your screen and start the install.\n
YOU CANNOT USE YOUR COMPUTER DURING THIS TIME!
	
If you would rather install it later, simply \"Exit\" this alert.

Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Install"
dButton2="Exit"
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Serial:__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"



		userTimeSelection=$(${dialog_bin} \
		    --title "$dTitle" \
			--titlefont "$dialogTitleFont" \
		    --message "$dMessage" \
			--messagefont "name=Arial-MT,size=30" \
		    --icon "$dIconDir" \
			--iconsize 120 \
		    --button1text "$dButton1" \
		    --button2text "$dButton2" \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--big \
			--background "$dBackDir" \
			--infobox "$dInfoBox" \
			--moveable 
	
		)		
		


		#Button pressed Stuff
		returncode=$?


		case ${returncode} in
		    0)  echo "Pressed Button 1: install"
			siliconCheck
		
			exit 0
		        ;;

		    2)  echo "Pressed Button 2: exit"
	
			exit 0

		        ;;
		
		    *)  echo "Something else happened. exit code ${returncode}"
			exit 0

		        ;;
		esac

}




#====================================







###=================================
#Download and Alert

downloadmacOS () {

	echo Downloading $macOSVersion
	#downloading InstallAssistant.pkg for Ventura
	curl -L "$macOSURL" -o "$macOSDir$macOSPKG"
	
	#install - extract "Install macOS Ventura.app"
	/usr/sbin/installer -pkg "$macOSDir$macOSPKG" -target /
	
	sleep 5
	#Cleanup - remove InstallAssistant.pkg
	sudo rm -rf "$macOSDir$macOSPKG"
    killall Dialog
	
	sleep 2
	


	echo "Verifying macOS Download..."
	if [ -a /Applications/Install\ macOS\ $dlmacOSName.app ]; then
		echo "App found... launch alert"
		askToInstall
		
		
		
	else
		echo "App not found... exiting"
	#	sudo jamf recon -room "macOS Update Fail"
		exit 
	fi


}





downloadmacOSAlert () {

dTitle="Side IT Alert: Downloading macOS"
dMessage="macOS $macOSVersion download has begun.
	
This will take some time. 
You are free to continue working during this process.
	
__DO NOT CLOSE THE SELF SERVICE APP OR IT COULD DISRUPT THE DOWNLOAD.__

Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
web="https://www.cultofmac.com/wp-content/uploads/2014/10/slinky_me_54467c11ddf8b.gif"
timer=2700 #60*45=2700
caffeineTimer=3600
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Serial:__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"



		caffeinate -i -s -d -t $caffeineTimer userTimeSelection=$(${dialog_bin} \
		    --title "$dTitle" \
			--titlefont "$dialogTitleFont" \
		    --message "$dMessage" \
			--messagefont "name=Arial-MT,size=30" \
		    --icon "$dIconDir" \
			--iconsize 120 \
			--helpmessage "$dHelp" \
			--helptitle "TITLE" \
			--big \
			--background "$dBackDir" \
			--infobox "$dInfoBox" \
            --webcontent "$web" \
			--timer "$timer" \
			--moveable 

		)	


}

###=================================

######## CHECKING FOR macOS Download


echo "Verifying macOS Download..."
if [ -a /Applications/Install\ macOS\ $dlmacOSName.app ]; then
	echo "App found... launch alert"
	askToInstall
	
	
	
else
	echo "App not found... continuing"
fi


######## CHECKING FOR macOS Download



dTitle="Side IT Alert: macOS Update"
dMessage="This policy is for updating macOS to the latest version - macOS $macOSVersion 

The download will NOT automatically install, you must manually trigger the installation. 
The download can take up to 30 min to complete depending on your internet bandwidth speed.

Click \"Download\" to start the process.
Click \"Dismiss\" if you prefer to perform this at a later time.

Contact helpdesk@side.com or #it-support in Slack with any questions.\n
Thank you!\n 
-Side IT."
dButton1="Download"
dButton2="Dismiss"
dIconDir="$dialogIconDir"
dBackDir="$dialogBackGroundDir"
dHelp="This notification is launched automatically by Side IT Helpdesk.\n
Please contact helpdesk@side.com or #it-support in Slack with any questions or concerns."
dInfoBox="__Current macOS:__ $currentOSVersion\n\n
__Update To:__
$macOSVersion\n\n
__Serial:__
$macSerial\n\n
__Slack__  
[#it-support]($dialogSlackURL)\n\n
__Support Ticket__  
[helpdesk@side.com]($dialogHDURL)"



	userTimeSelection=$(${dialog_bin} \
	    --title "$dTitle" \
		--titlefont "$dialogTitleFont" \
	    --message "$dMessage" \
		--messagefont "name=Arial-MT,size=30" \
	    --icon "$dIconDir" \
		--iconsize 120 \
	    --button1text "$dButton1" \
	    --button2text "$dButton2" \
		--helpmessage "$dHelp" \
		--helptitle "TITLE" \
		--big \
		--background "$dBackDir" \
		--infobox "$dInfoBox" \
		--moveable 
	
	)		
		


	#Button pressed Stuff
	returncode=$?


	case ${returncode} in
	    0)  echo "Pressed Button 1: download"
		#code to download
		
		downloadmacOS & downloadmacOSAlert
		
		exit 0
	        ;;

	    2)  echo "Pressed Button 2: dismiss"
	
		exit 0

	        ;;
		
	    *)  echo "Something else happened. exit code ${returncode}"
		exit 0

	        ;;
	esac
