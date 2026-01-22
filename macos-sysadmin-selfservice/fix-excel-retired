#!/bin/bash
if [ -f ~/Library/Preferences/com.microsoft.Excel.plist ]
then
RESULT="File found... Removing..."
sudo rm -r ~/Library/Preferences/com.microsoft.Excel.plist
if [ -f ~/Library/Preferences/com.microsoft.Excel.plist ]
then
RESULT2="Deletion Failed"
else
RESULT2="Deletion Complete!"
fi
else
RESULT="File not found"
RESULT2=""
fi
mail -s "$(scutil --get LocalHostName) - Excel Fix" [day9consulting@gmail.com](mailto:day9consulting@gmail.com) pc$
$(scutiul --get LocalHostName)
Result1 - $RESULT
Result2 - $RESULT2

EOF
