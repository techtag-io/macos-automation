#!/bin/bash
sudo rm -rvf ~/Library/Application\ Support/Microsoft
sudo rm -R ~/Library/Preferences/com.microsoft.autoupdate2.plist
sudo rm -R ~/Library/Preferences/com.microsoft.error_reporting.plist
sudo rm -R ~/Library/Preferences/com.microsoft.office.plist
sudo rm -R ~/Library/Preferences/com.microsoft.office.setupassistant.plist
sudo rm -R ~/Library/Preferences/com.microsoft.outlook.database_daemon.plist
sudo rm -R ~/Library/Preferences/com.microsoft.outlook.office_reminders.plist
sudo rm -R ~/Library/Preferences/com.microsoft.Outlook.plist
sudo rm -R ~/Library/Preferences/com.microsoft.Word.plist
sudo rm -R ~/Library/Preferences/com.microsoft.Excel.plist
sudo rm -R ~/Library/Preferences/com.microsoft.Powerpoint.plist
sudo rm -rvf /Applications/Microsoft\ Office\ 2011
if [ -e /Applications/Microsoft\ Office\ 2011/Microsoft\ Word.app ]
then
RESULT="Office Failed to delete"
else
RESULT="Office succesfully deleted"
sudo rm -rf ~/.Trash/*
fi
mail -s "$(scutil --get LocalHostName) - Office Removed" day9consulting@gmail.c$
$(scutil --get LocalHostName) - $RESULT
EOF

sudo reboot
