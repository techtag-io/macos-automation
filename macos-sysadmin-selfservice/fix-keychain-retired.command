#!/bin/bash
if [ -d ~/Library/Keychains ]
then
RESULT="Keychain folder found"
sudo rm -Rf ~/Library/Keychains
if [ -d ~/Library/Keychains ]
then
RESULT2="Keychain Fix Failed"
else
RESULT2="Keychain Fix Seccessfull"
fi
else
RESULT="Keychain folder not available"
fi
mail -s "$(scutil --get LocalHostName) - Keychain Fix" day9consulting@gmail.com$
Machine:
$(scutil --get LocalHostName)
Result:
$RESULT
If Keychain Folder Is Found:
$RESULT2

EOF
