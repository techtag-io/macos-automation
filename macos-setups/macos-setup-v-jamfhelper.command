#!/bin/sh

# wait until the Self Service process has started
while [[ "$setupProcess" = "" ]]
do
	echo "Waiting for Self Service..."
	setupProcess=$( /usr/bin/pgrep "Self Service" )
	sleep 3
done

#intialiaizng
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/finishing.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup Starting..." -description "Preparing Setup... Please make sure the computer is connected to a power source." & sleep 5



#chrome
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/chrome.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
1 of 4: Installing Google Chrome..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event googlechrome

#drive
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/drive.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
2 of 4: Installing Google Drive..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event googledrive

#slack
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/slack.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
3 of 4: Installing Slack..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event slack

#zoom & set dock (first run)
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/zoom.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
4 of 4: Installing Zoom..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event zoominfo; sudo jamf policy -event modifyDock

#settings > machine name
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
Applying Settings 1 of 4..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event mbpname

#settings > user fill
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
Applying Settings 2 of 4..." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event uploadUser

#settings > inSiderIntranet App
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
Applying Settings 3 of 4...." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event inSiderIntranet

#small break
sleep 3

#settings > dock
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/settings.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress... 
Applying Settings 4 of 4...." -description "Please make sure the computer is connected to a power source." & sudo jamf policy -event modifyDock

#settings > filevault login alert
/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType fs -icon /Library/Application\ Support/SideIT/filevaultenable.png -title "Side, Inc Laptop Setup" -heading "Side, Inc Computer Setup in progress...
Setup completing." -description "At the next login, please be sure to ENABLE FileVault! 
Restarting device..." & sleep 5

#close self service before rebooting
killall Self\ Service
