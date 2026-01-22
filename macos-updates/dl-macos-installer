#!/bin/bash


#Downloading macOS Update

#macOS InstallAssistant PKG - this will contain and exract Install macOS Ventura.app
#macOSURL - 13.5.2 - updated 08.08.2023
macOSURL='https://swcdn.apple.com/content/downloads/13/14/042-43677-A_H6GWAAJ2G9/6yl1pnz2f3m5sg2b4gpic7vz2i1s1n9n23/InstallAssistant.pkg'
macOSDir="/tmp/"
macOSPKG="InstallAssistant.pkg"

#Check for Installer
macOSInsDir="/Applications/Install macOS Ventura.app"


downloadMacOS () {

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
	echo "Installer downloaded successfully, ready to install"
	exit 0
else
	echo "Installer failed, submitting ticket and exiting script"
	sudo jamf recon -room "macOS Update Fail"
	exit 0
fi #fi for installer check after download

}






if [ -a "$macOSInsDir" ]; then
	echo "Installer found, removing old installer and downloading latest version"
	sudo rm -rf "/Applications/Install macOS Ventura.app"
	
else
	echo "Installer not found, downloading"
	
fi #fi for primary installer check

downloadMacOS
