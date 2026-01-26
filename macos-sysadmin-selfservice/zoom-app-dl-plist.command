#!/bin/bash

#Downloading and installing Zoom

url="https://zoom.us/client/latest/ZoomInstallerIT.pkg"

#setting directories

pkgfile='Zoom.pkg'
dir='/tmp/'$pkgfile


#Downloading PKG
echo "Downloading..."
/usr/bin/curl -L -o $dir ${url} 

echo "Sleep 5"
#Small break
Sleep 5

echo "Installing..."
#Installing PKG
sudo installer -pkg $dir -tgt / -verbose

echo "Sleep 5"
#Give it a break
sleep 5

#Delete the temp file
echo "Cleanup..."
sudo rm -Rf $dir

#Close Zoom app
#echo "Closing Zoom app..."
#killall zoom.us

#This creates a PLIST that is placed in /Library/Managed Preferences.
#on install of zoomIT.pkg, it then opens the app and forces the user to log in VIA SSO
#FB and Google are disabled for login options

echo "Creating PLIST..."
#Creating PLIST
cat > /Library/Preferences/us.zoom.config.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>nogoogle</key>
	<true/>
	<key>nofacebook</key>
	<true/>
	<key>zDisableVideo</key>
	<true/>
	<key>zAutoJoinVoip</key>
	<true/>
	<key>zAutoSSOLogin</key>
	<true/>
	<key>zSSOHost</key>
	<string>sideinc.zoom.us</string>
	<key>EnableShareVideo</key>
	<false/>
	<key>zRemoteControlAllApp</key>
	<true/>
    <key>zAutoFullScreenWhenViewShare</key>
	<false/>
	<key>zAutoFitWhenViewShare</key>
	<true/>
	<key>zAutoUpdate</key>
	<true/>
	<key>EnableSilentAutoUpdate</key>
	<true/>
</dict>
</plist>

EOF
echo "PLIST Created..."


exit 0
