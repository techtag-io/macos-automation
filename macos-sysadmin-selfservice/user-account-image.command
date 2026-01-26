#!/bin/bash

echo "Pull user"
usernamepull="$(stat -f%Su /dev/console)"
echo "User: "$usernamepull

echo "dscl read user"
dscl . read /Users/$usernamepull

echo "dscl delete user photo"
dscl . delete /Users/$usernamepull JPEGPhoto

echo "dscl set user photo"
dscl . create /Users/$usernamepull Picture "/Library/Application Support/wallpaper/side.png"
