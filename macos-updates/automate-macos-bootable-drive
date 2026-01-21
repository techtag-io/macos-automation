#Ceated by Andrew Bergstrom as fun project to start learning bash scripting

#!/bin/bash

installSwiftDialog () {
	
	updatedDialogVersion="$4"
	dialog_bin="/usr/local/bin/dialog"
	dialog_download_url="$5"
	dialogDir='/usr/local/'
	swiftDialogPKG="swiftDialog.pkg"
	dialogAppDir="/Library/Application Support/Dialog/Dialog.app"

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

# alerts user that no USB is attached to the device and prompts them to do so
noUSB () {

 dialog_bin="/usr/local/bin/dialog"

 pIcon="https://cdn-icons-png.flaticon.com/512/2972/2972093.png"

 picon="https://512pixels.net/wp-content/uploads/2021/06/12-Dark-thumbnail-768x768.jpg"

 pTitle="No Thumbdrive Detected"

 pMessage="
 No attached thumbdrive has been detected on your device.\n 

 Please attach a thumbdrive to your computer to continue. Once a thumbdrive has been attached click 'Try again' or wait for the timer to finish. 
 
 Clicking 'Cancel' will exit the app.\n\n

 "

 pButton1text="Try Again"
 pButton2text="Cancel"

 bootableinstallation=$(${dialog_bin} \
 	--bannertitle "$pTitle" \
 	--message "$pMessage" \
 	--icon "$pIcon" \
 	--bannerimage "$picon" \
 	--big \
	--moveable \
 	--timer \
 	--button1text "$pButton1text" \
 	--button2text "$pButton2text" \
  	--messagefont "name=Arial-MT,size=30" 

 )
	
	 # Update the global variable or manage the return code at the end of the function
	     returncodeUSB=$?


	 # Return the code to caller
		 return $returncodeUSB

}

# detects whether or not a USB is attached to the device, if none is detected then prompts "noUSB" dialogue and loops until USB is detected
while true; do
    tmp_file=$(mktemp)

    find /Volumes/* -maxdepth 0 -type d ! -name "Macintosh HD" -exec basename {} \; | grep -v "Data" > "$tmp_file"
    
    if [ ! -s "$tmp_file" ]; then
        echo "No USB thumb drives are currently connected. Starting dialog loop."
        noUSB
        if [ "$returncodeUSB" -eq 2 ]; then  
            echo "User cancelled the operation."
			rm "$tmp_file"
            exit 0
        fi
        echo "No USB detected. Retrying..."
    else
        echo "USB drive detected."
        break
    fi
    sleep 1 
done
	
 # Format thumb drive list as comma-separated items in double quotes
 thumb_drive_list=""
 while IFS= read -r line; do
     thumb_drive_list+="\"$line\", "
 done < "$tmp_file"
 thumb_drive_list="${thumb_drive_list%, }"  # Remove the trailing comma and space

 echo "Thumb drive list in JSON format:"
 echo "$thumb_drive_list"

 # Clean up temporary file
 rm "$tmp_file"


# to call welcome dialog
thumbDriveWelcomeDialog () {
	

macOSversion=$(sw_vers -productVersion)
dialog_bin="/usr/local/bin/dialog"

dicon="https://512pixels.net/wp-content/uploads/2021/06/12-Dark-thumbnail-768x768.jpg"

dTitle="Welcome to the macOS Bootable Thumbdrive Installer!"

dMessage="
This tool will create a bootable version of the latest macOS software on an attached thumbdrive.\n
Please ensure that a thumbdrive is attached before running this script.\n

You may exit this process by clicking the 'Cancel' button.\n\n

Please reach out to helpdesk@side.com with any questions."
thumbdriveButton="Select Thumbdrive"
cancelButton="Cancel"


userTimeSelection=$(${dialog_bin} \
--bannertitle "$dTitle" \
--message "$dMessage" \
--bannerimage "$dicon" \
--big \
--moveable \
--messagefont "name=Arial-MT,size=30" \
--button1text "$thumbdriveButton" \
--button2text "$cancelButton"

)
	
	#Buttons pressed
	returncodewelcome=$?


	case ${returncodewelcome} in
	    0)  echo "Pressed Button 1: Select Thumbdrive - thumbDriveWelcomeDialog"
		thumbDriveChoice
	
	        ;;

	    2)  echo "Pressed Button 2: Cancel - thumbDriveWelcomeDialog"
		    killall Dialog
		exit 0

	        ;;
	
	    *)  echo "Someone did something dumb. exit code ${returncode}"
		exit 0

	        ;;
	esac
	
}

# lets user select which thumbdrive they would like to install the bootable on
thumbDriveChoice () {
	
dialog_bin="/usr/local/bin/dialog"

dicon="https://cdn-icons-png.flaticon.com/512/2972/2972093.png"

dTitle="Thumbdrive Selector"

dMessage="
Select which thumbdrive you would like use as a macOS bootable from the list of available drives below. 

**This process will wipe any data on the drive you select. Please ensure any important information is transferred or it will be lost.**
"
driveselectButton="Create macOS Bootable"
bCancelButton="Cancel"
driveselect="Select Thumbdrive"

# create a comma-separated list
#usb_drive_list="${usb_drives[@]}"
usb_drive_list="$thumb_drive_list"


thumbDriveSelection=$(${dialog_bin} \
--title "$dTitle" \
--message "$dMessage" \
--icon "$dicon" \
--moveable \
--selecttitle "$driveselect" \
--selectvalues "$usb_drive_list" \
--messagefont "name=Arial-MT,size=25" \
--button1text "$driveselectButton" \
--button2text "$bCancelButton"

)
	

	#Buttons pressed
returncodeselect=$?

case ${returncodeselect} in
	    0)  echo "Pressed Button 1: Create macOS Bootable - thumbDriveChoice"
			# Check the user's selection 
			selected_drive=$(echo "$thumbDriveSelection" | grep -oE '[^,]+')
			drivename=$(echo "$selected_drive" | grep "SelectedOption" | awk -F " : " '{print $NF}')
			drivename=${drivename//\"} 
			echo "Selected Drive: $drivename"
		    passwordprompt
	        ;;

	    2)  echo "Pressed Button 2: Cancel - thumbDriveChoice"
		    killall Dialog
	        exit 0
	        ;;

	    *)  echo "Someone did something dumb. exit code ${returncode}"
	        exit 0
	        ;;
esac

	
}

# pulls current user and echos for password check later
currentUser=$( echo "show State:/Users/ConsoleUser" | scutil | awk '/Name :/ { print $3 }' )
echo "Current User:" $currentUser

# Ask for Password and verify it is correct before proceeding
passwordprompt () {
	
passCheck="null"


    until [ $passCheck == "PASSED" ]; do
        if [ "$passCheck" != "FAILED" ]; then
            bTitle="Password Required"
            passwordneeded="Administrator permissions are required to set up a bootable thumbdrive. \n\nPlease enter your password in the field below and click the continue button once finished.\n\nYou may exit this process by clicking the 'Cancel' button."
        else
            bTitle="Incorrect Password"
            passwordneeded="Administrator permissions are required to set up a bootable thumbdrive. \n\nPlease enter your password in the field below and click the continue button once finished.\n\nYou may exit this process by clicking the 'Cancel' button.\n\n_**Incorrect Password. Try again.**_"
        fi

        dialog_bin="/usr/local/bin/dialog"
        dialog_command=("${dialog_bin}" \
            --title "$bTitle" \
            --titlefont "name=Arial-MT,colour=#FF0000,size=30" \
            --message "$passwordneeded" \
            --icon "https://icons-for-free.com/iff/png/256/lock-131965017477184994.png" \
            --big \
            --messagefont "name=Arial-MT,size=30" \
            --button1text "Continue" \
            --button2text "Cancel" \
            --textfield "Password,required,secure")

        userPasswordPrompt=$("${dialog_command[@]}")
		
		#Buttons pressed
		returncode=$?
	
		# Exit the script if cancel button is pressed
		        if [ "$returncode" -eq 2 ]; then
		            echo "Cancel button pressed. Exiting script."
		            exit 0
		        fi
	
	#Store the entered password
	userpass=$userPasswordPrompt
	userpass_trimmed="${userpass:11}"
	
	#uncomment for user password
	#echo "$userpass"
	#echo "$userpass_trimmed"
	
	#real password check
	dscl . authonly "$currentUser" "$userpass_trimmed" &> /dev/null; resultCode=$?
		if [ "$resultCode" -eq 0 ];then
	    	echo "Password Check: PASSED"
			passCheck="PASSED"
			
		else
	    	# Prompt for User Password
	    	echo "Password Check: WRONG PASSWORD"
	    	#wrongUserPassword
			passCheck="FAILED"
		fi
		
	done
	
	case ${returncode} in
	    0)  echo "Pressed Button 1: Continue - passwordprompt"
		macOSinstaller
	
	        ;;

	    2)  echo "Pressed Button 2: Cancel - passwordprompt"

		exit 0

	        ;;
	
	    *)  echo "Someone did something dumb. exit code ${returncode}"
		exit 0

	        ;;
	esac	
	
}

# Dialog to let user know a macOS installer is being downloaded for them 
installmacOSbootable () {
	
dialog_bin="/usr/local/bin/dialog"

mIcon="https://cdn-icons-png.flaticon.com/512/2972/2972093.png"

picon="https://512pixels.net/wp-content/uploads/2021/06/12-Dark-thumbnail-768x768.jpg"

dTitle="Downloading macOS Installer"

pMessage="
A macOS installer was not detected on your device so one is being downloaded for you automatically. Once the download is complete this dialog will close and the script will continue.\n 

Please be sure to keep your device running during this process!\n\n
"

dWeb="https://www.icegif.com/wp-content/uploads/2022/11/icegif-1506.gif"

bootableinstallation=$(${dialog_bin} \
	--bannertitle "$dTitle" \
	--message "$pMessage" \
	--icon "$mIcon" \
	--bannerimage "$picon" \
	--big \
	--moveable \
	--button1text none \
	--webcontent "$dWeb" \
 	--messagefont "name=Arial-MT,size=28" 

)

}

# lets user know that the bootable setup is in progress and closes once complete
bootablesetup () {
	
dialog_bin="/usr/local/bin/dialog"

dIcon="https://cdn-icons-png.flaticon.com/512/2972/2972093.png"

bicon="https://512pixels.net/wp-content/uploads/2021/06/12-Dark-thumbnail-768x768.jpg"

dTitle="MacOS bootable setup in progress!"

dMessage="
Please ensure that the attached thumbdrive is not removed while the setup is in progress.\n 
The download and thumbdrive creation could take up to 60 minutes depending on internet speed.\n
This window will close automatically once the setup is complete.

"
web="https://www.icegif.com/wp-content/uploads/2022/11/icegif-1506.gif"


bootableinstallation=$(${dialog_bin} \
	--bannertitle "$dTitle" \
	--message "$dMessage" \
	--icon "$dIcon" \
	--bannerimage "$bicon" \
	--big \
    --moveable \
	--webcontent "$web" \
	--button1text none \
	--messagefont "name=Arial-MT,size=25" 

)

}

# Dialogue to show that the setup has completed
setupcomplete () {

dialog_bin="/usr/local/bin/dialog"

fIcon="https://cdn-icons-png.flaticon.com/512/2972/2972093.png"

bicon="https://512pixels.net/wp-content/uploads/2021/06/12-Dark-thumbnail-768x768.jpg"

fTitle="MacOS bootable setup complete!"

fMessage="
Your thumbdrive should now be named 'Install macOS Sonoma' with an installer downloaded to it.\n 

Please make sure to double check that the install was set up properly and the eject the thumbdrive from your device once finished and you're all set!\n\n

"

bootableinstallation=$(${dialog_bin} \
	--bannertitle "$fTitle" \
	--message "$fMessage" \
	--icon "$fIcon" \
	--bannerimage "$bicon" \
	--big \
	--moveable \
 	--messagefont "name=Arial-MT,size=30" 

)
	
	#Buttons pressed
	returncodecomplete=$?


	case ${returncodecomplete} in
	    0)  echo "Pressed Button 1: Complete"
		exit 0
	
	        ;;
	
	    *)  echo "Someone did something dumb. exit code ${returncode}"
		exit 0

	        ;;
	esac

}

# Detects whether or not a macOS installer is on the device and installs one if not. Opens dialogue to let user know it is installing and closes once complete
macOSinstaller () {
	
    INSTALLER_APP=$(find /Applications -type d -name "Install macOS *.app")
    
    if [ -a "$INSTALLER_APP" ]; then
        echo "macOS Installer Found, proceeding"
    else
        echo "macOS Installer Not Found, downloading"
        # Download the latest macOS installer in the background
        macOSversion=$(sw_vers -productVersion)
        softwareupdate --fetch-full-installer --full-installer-version $macOSversion &
        pid=$!  # Save the PID of the softwareupdate process
        installmacOSbootable &  # Call the dialog function to inform user
        wait $pid  # Wait for the softwareupdate to finish
        killall Dialog  # Optionally kill the dialog if it's still running
	
    fi

    # Call the next step or handle completion
    bootableinstallation
}

# Create the bootable installer on the USB drive
bootableinstallation () {
	
    
    echo "$userpass_trimmed" | sudo -S "$INSTALLER_APP/Contents/Resources/createinstallmedia" --volume "/Volumes/$drivename" --nointeraction &
    createinstallmedia_pid=$! # Save the PID of the createinstallmedia process
    bootablesetup # Call the function to show the dialog
    wait $createinstallmedia_pid # Wait for the createinstallmedia to finish
    killall Dialog # Close all Dialog windows
	
    # Call the setupcomplete function after the bootable setup process is complete
	setupcomplete
}



# Call functions
installSwiftDialog

thumbDriveWelcomeDialog
