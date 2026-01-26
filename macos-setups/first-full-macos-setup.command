#!/bin/bash

### Script created by Travis McGowan - 2018.07.11
### This script will put a number of specific files in very specific locations, and download others in very specfic locations and perform the following:
### Install Apps: Google Chrome, Google Drive File Stream, Slack, CarbonBlack AV, GlobalProtect VPN client + PLIST, YASU, GrandPerspective, AppCleaner, All office printers, launch XCODE tools installer, Meraki agent and mdm.config
### Install Settings: Turn on FileVault with a specific Keychain, Enable ARD, Turn off auto updates, create an Admin Rescue account called "pgrescue", installs PLIST for to give new accounts admin privileges.
### Work in progress: Bind to AD (dozer.plangrid.com) - testing with .mobileconfig file, Verification of items installed (apps and settings) - 
### Github link: https://raw.githubusercontent.com/SpidrWeb/macOSImage/master/macOSImage.command
### Terminal run:  <curl https://raw.githubusercontent.com/SpidrWeb/macOSImage/master/macOSImage.command | bash -s arg1 arg2>

# Files that are put in place with PKG (non scripted download / not using curl):
#
# FileVault
# /Library/Keychains/FileVaultMaster.keychain
# /Library/PGFiles/FVPL.plist
#
# CarbonBlack
# /Library/CarbonBlack/CbDefense\ Install.pkg
# /Library/CarbonBlack/cbdefense_install_unattended.sh
#
# Meraki Agent
# /Library/MerakiInstaller.pkg
#
# Meraki .config
# /Library/PGFiles/meraki_sm_mdm.mobileconfig
#
# AD Bind using .mobileconfig
#
# Printers
# /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L8850CDW\ CUPS.gz
# /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L9550CDW\ CUPS.gz
#
# Make logged in user Admin
# /Library/LaunchAgents/com.userprivs.pg.plist (will call next line)
# /Library/PGFiles/fullWork.command



#Create folders as file repository
sudo mkdir /Library/PGFiles
sudo mkdir /Library/CarbonBlack
#sudo mkdir ~/Desktop/Logs -- coming soon

#Start downloading and installng...
##########################################################

#Meraki Agent:
sudo installer -pkg /Library/PGFiles/MerakiInstaller.pkg -tgt / -verbose


##########################################################

#Meraki .config installer
sudo /usr/bin/profiles -I -F /Library/PGFiles/meraki_sm_mdm.mobileconfig


##########################################################

#ADBind .config installer - will bind to dozer.plangrid.com
sudo /usr/bin/profiles -I -F /Library/PGFiles/ADBind.mobileconfig


##########################################################

#Enable ARD:

sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -allowAccessFor -specifiedUsers
sudo /System/Library/CoreServices/RemoteManagement/ARDAgent.app/Contents/Resources/kickstart -activate -configure -users pgadmin -access -on -privs -DeleteFiles -ControlObserve -TextMessages -OpenQuitApps -GenerateReports -RestartShutDown -SendFiles -ChangeSettings


##########################################################

#Set Dock icons:

#Add Slack to Dock
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Slack.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"

#Add Chrome to Dock
defaults write com.apple.dock persistent-apps -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Google Chrome.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"


##########################################################

#Call Chrome - Direct Download

sudo curl -o /Library/PGFiles/googlechrome.dmg https://dl.google.com/chrome/mac/stable/GGRO/googlechrome.dmg
hdiutil attach /Library/PGFiles/googlechrome.dmg
cp -r /Volumes/Google\ Chrome/Google\ Chrome.app /Applications/Google\ Chrome.app
hdiutil eject /Volumes/Google\ Chrome


##########################################################

#Call Drive File Stream - Direct Download

sudo curl -o /Library/PGFiles/GoogleDriveFileStream.dmg https://dl.google.com/drive-file-stream/GoogleDriveFileStream.dmg
hdiutil mount /Library/PGFiles/GoogleDriveFileStream.dmg
sudo installer -pkg /Volumes/Install\ Google\ Drive\ File\ Stream/GoogleDriveFileStream.pkg -target "/Volumes/Macintosh HD"
hdiutil unmount /Volumes/Install\ Google\ Drive\ File\ Stream/


##########################################################

#Call Slack - Downloads from DropBox, Slack direct link does not exist

curl -o /Library/PGFiles/Slack.zip https://dl.dropboxusercontent.com/s/2vhtwivr0e9t4gb/SlackTest.zip?dl=0
unzip /Library/PGFiles/Slack.zip -d /Applications/


########################################################## >>>>>>>>>>> NEEDS SPECIFIC FILES

#Call CarbonBlack						
#Files are put in /Library/CarbonBlack

sudo /Library/CarbonBlack/cbdefense_install_unattended.sh


########################################################## >>>>>>>>>>> NEEDS SPECIFIC FILES

#Call GlobalProtect

#Download GlobalProtectInstaller.pkg
sudo curl -o /Library/PGFiles/GlobalProtectInstaller.pkg https://dl.dropboxusercontent.com/s/pje4zztqqol3z1s/GlobalProtectInstaller.pkg?dl=0

#Downloading PLIST into /Library/Preferences
sudo curl -o /Library/Preferences/com.paloaltonetworks.GlobalProtect.plist https://dl.dropboxusercontent.com/s/yf3121z8ovmdwu5/com.paloaltonetworks.GlobalProtect.plist?dl=0

#Install GlobalProtectInstaller.pkg Silently
sudo installer -pkg /Library/PGFiles/GlobalProtectInstaller.pkg -target /


########################################################## >>>>>>>>>>> NEEDS SPECIFIC FILES

#Turn on FileVault
#Files are put in place: /Library/Keychains (KEYCHAIN) + /Library/PGFiles (PLIST)

sudo fdesetup enable -keychain -defer /Library/PGFiles/FVPL.plist -forceatlogin 0 -dontaskatlogout


##########################################################

#Call GrandPerspective - Downloads from DropBox - direct link does not exist

curl -o /Library/PGFiles/GrandPerspective.zip https://dl.dropboxusercontent.com/s/hm6p4g0kkx0hw65/GrandPerspective.zip?dl=0
unzip /Library/PGFiles/GrandPerspective.zip -d /Applications/
sudo rm -rf /Applications/__MACOSX


##########################################################

#Call AppCleaner - Direct Download

curl -o /Library/PGFiles/AppCleaner.zip https://freemacsoft.net/downloads/AppCleaner_3.4.zip
unzip /Library/PGFiles/AppCleaner.zip -d /Applications/
sudo rm -rf /Applications/__MACOSX


##########################################################

#Call Yasu - Downloads from DropBox, Direct link does not exist - Downloads HighSierra Version

curl -o /Library/PGFiles/Yasu.zip https://dl.dropboxusercontent.com/s/be5intgf8364vio/yasu_1013.zip?dl=0
unzip /Library/PGFiles/Yasu.zip -d /Applications/
rm -r /Applications/__MACOSX


##########################################################

#Create pgrescue account
#Create Account
sudo dscl . create /Users/pgrescue

#Enable Account
sudo dscl . create /Users/pgrescue UserShell /bin/bash

#Set Full Name
sudo dscl . create /Users/pgrescue RealName "PG Rescue"

#Set Account ID (499< will be hidden)
sudo dscl . create /Users/pgrescue UniqueID 510

#Set Account In Machine Group
sudo dscl . create /Users/pgrescue PrimaryGroupID 80

#Create the directory to be found in GUI
sudo dscl . create /Users/pgrescue NFSHomeDirectory /Local/Users/pgrescue

#Give Accounts Admin Writes
sudo dscl . -append /Groups/admin GroupMembership pgrescue

#Give account a Password
#Without Password Policy
sudo dscl . passwd /Users/pgrescue gr1D.R3scu3

#With Password Policy
#dscl . passwd /Users/[account name] > ENTER > Type in [password] OR
#     sudo passwd [account name] > Enter > Type in [password]


####################################################### >>>>>>>>>>> NEEDS SPECIFIC FILES (Drivers)

#Call Printers
#Brother MFC-L8850CDW

#Engineering: 10.10.0.253
lpadmin -p Engineering -L "Engineering" -E -v ipp://10.10.0.253  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L8850CDW\ CUPS.gz -o printer-is-shared=false

#Accounting: 10.10.1.112
lpadmin -p Accounting -L "Accounting" -E -v ipp://10.10.1.112  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L8850CDW\ CUPS.gz -o printer-is-shared=false

#Sales: 10.10.2.35
lpadmin -p Sales -L "Sales" -E -v ipp://10.10.2.35  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L8850CDW\ CUPS.gz -o printer-is-shared=false

#Reception: 10.10.0.155
lpadmin -p Reception -L "Reception" -E -v ipp://10.10.0.155  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L8850CDW\ CUPS.gz -o printer-is-shared=false

##>><<##

#Brother MFC-L9550CDW

#Marketing: 10.10.2.229
lpadmin -p Marketng -L "Marketing" -E -v ipp://10.10.2.229  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L9550CDW\ CUPS.gz -o printer-is-shared=false


#HR-Only: 10.10.1.238 - uncomment to install
#lpadmin -p HR-Only -L "HR-Only" -E -v ipp://10.10.1.238  -P /Library/Printers/PPDs/Contents/Resources/Brother\ MFC-L9550CDW\ CUPS.gz -o printer-is-shared=false


##########################################################

#Turn AutoUpdates OFF
sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -boolean FALSE


##########################################################

#Reset Dock for shortcuts
killall Dock

##########################################################


#Make User Account an Admin - gives permission to PLIST and launches
chflags hidden /Library/hide #hide folder with password - use "nohidden" to reveal
sudo chown root /Library/LaunchAgents/com.userprivs.pg.plist
sudo chgrp /Library/LaunchAgents/com.userprivs.pg.plist
sudo launchctl load -w /Library/LaunchAgents/com.userprivs.pg.plist

##########################################################

#Download XCode Tools - will launch UI installer
xcode-select --install

##########################################################
