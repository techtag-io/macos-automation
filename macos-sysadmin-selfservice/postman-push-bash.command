#!/bin/bash

## SELECT PROD VS STAGE AND SET BASEURL
       
buttonClicked=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -lockHUD -icon /Library/Application\ Support/SideIT/ATTIcon.png -title "Side App Patcher" -heading "Please Select" -description "
Prod: Side App
If user is being created in PROD Okta with Org2Org to Agent Okta


Staging: Side App Staging
If user is being created in SandBox Okta with Org2Org to SandBox Agent Okta


" -button1 "Prod" -button2 "Staging")

	#-button1 - update now
	if [ $buttonClicked == 0 ]; then
		echo "Side App: baseURL set to https://admin-api.sideinc.com/v1/users/"
		baseURL='https://admin-api.sideinc.com/v1/users/'
		accessType='Side App UID: '
		
	else
		echo "Side App Staging: baseURL set to: https://admin-api-stage.sideinc.dev/v1/users/"
		baseURL='https://admin-api-stage.sideinc.dev/v1/users/'
		licenseNumber='000000000'
		cellNumber='0000000000'
		accessType='Side App Staging UID: '
		
fi


##################
#User Input:
#Side Agent OKTA ID - TURN ON IF YOU WANT USER TO INPUT OKTA ID
#oktaID=`osascript -e 'set T to text returned of (display dialog "Agent OKTA User ID:" buttons {"Cancel", "OK"} default button "OK" default answer "")'`

#echo "Agent Okta User ID is: "$oktaID

#email
emailAdd=`osascript -e 'set T to text returned of (display dialog "Type in users Email Address :" buttons {"Cancel", "OK"} default button "OK" default answer "")'`
echo $emailAdd
#lower case it
emailAdd=$(echo $emailAdd | tr "[:upper:]" "[:lower:]" )


echo Email Address is $emailAdd

#cell number - numbers only, no dashes
if [ "$cellNumber" == "0000000000" ]; then
	echo "filled"
else
echo "not filled"
cellNumber=`osascript -e 'set T to text returned of (display dialog "Type in users Cell Number - ONLY NUMBERS and NO DASHES ( ex: 4153269923 ) - IF NONE, KEEP BLANK:" buttons {"Cancel", "OK"} default button "OK" default answer "")'`

fi

echo Cell Number is $cellNumber

#License Number

if [ "$licenseNumber" == "000000000" ]; then
	echo "filled"
else
	echo "not filled"
	licenseNumber=`osascript -e 'set T to text returned of (display dialog "Type in users Licesense Number - ONLY NUMBERS and NO DASHES ( ex: 21223656 ) - IF NONE, KEEP BLANK:" buttons {"Cancel", "OK"} default button "OK" default answer "")'`
	
fi

echo License Number is $licenseNumber



#Role
####### Role/Mirror Selection - $roleMirror
theRole=$(osascript <<AppleScript

set userRoles to {"Account Setup", "Admin", "Admin Plus Finance", "Admin Plus Finance And Expert", "Agent Services", "Assistant", "Associate Agent", "Associate Agent TC", "Auditor", "Auditor Admin", "Business Manager", "Community Only", "Demo", "Email Templater", "Financials Super Admin", "Financials Super Admin With Docs", "Financials View Only", "Financials Writer", "Financials Writer With Docs", "Managing Broker", "Partner Agent", "Partner Agent TC", "Super Admin", "Tc", "Team TC", "Templater", "Templater-tc", "Transactions Ops Specialist", "Upworker", "Mirror Email Instead"}

set selectedRole to {choose from list userRoles}

AppleScript
)
	echo "${theRole}"
	
	var=$theRole
	
	noSpaces=${var//[[:blank:]]/}
	echo "No Spaces is: "$noSpaces
	
	userRole=$(awk -vFS= -vOFS= '{$1=tolower($1)}1' <<< "$noSpaces")
	echo "User Role is: "$userRole

#####Role/Mirror end



##########################
#GET Side App username via email address
#to pull via okta id, turn on the above user input and change URL to this: 'https://admin-api.sideinc.com/v1/users/?filterType=email&search='$oktaID
#https://admin-api.sideinc.com/v1/users/?filterType=email&search='$emailAdd

#oktaID='00u6asvr1ewpd5VSj5d7' #david jackson
tmpDir=/tmp/sideAppUserID.txt

echo $(curl --location --request GET $baseURL'?filterType=email&search='$emailAdd \
--header 'Authorization: hmac -<key>:<key>') >> $tmpDir

sleep 5

echo "pulling last 32 characters from file"
pullLast32=$(cat -n $tmpDir | tail -c 32)

echo "trimming out the user ID"
sideID=${pullLast32%???}
echo "Side App User ID: "$sideID
echo ""
echo ""

rm -rf $tmpDir
###########################


#sideID='<key>'
#set attributes
#authStr=':<key>'
getCode=$(echo -n "/v1/users/" | openssl dgst -sha256 -hmac "<key>")
patchCode=$(echo -n "/v1/users/$sideID" | openssl dgst -sha256 -hmac "<key>")


apiKeyId='key goes here'$patchCode


#curl to PATCH
accountResult=$(curl --location --request PATCH $baseURL$sideID \
--header 'Authorization: hmac '$apiKeyId \
--header 'Content-Type: application/json' \
--data-raw '{
    "docusignEmail": "'$emailAdd'",
    "cellPhoneNumber": "'$cellNumber'",
    "role": "'$userRole'",
    "accountTypes": ["developer"],
    "mlsSubscriptions": {
        "0": "sfar"
    },
    "brokerage": {
        "name": "Side",
        "street": "580 4th St",
        "city": "San Francisco",
        "state": "CA",
        "zip": "94107",
        "licenseNumber": "'$licenseNumber'",
        "phone": "415-525-4913",
        "email": "it@sideinc.com"
    },
    "teamId": "<ID>",
    "teamName": "Side",
    "primaryMLS": "sfar"
}')
$accountResult	

echo "apiKeyId: "$apiKeyId
echo "emailAdd: "$emailAdd
echo "roleID: "$userRole
echo "cellNum: "$cellNumber
echo "licenseNum: "$licenseNumber
echo "sentTo: "$baseURL$sideID


buttonClickedResults=$(/Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -icon /Library/Application\ Support/SideIT/ATTIcon.png -title "Side, Inc Alert!" -heading "Side App" -description "User account PATCHing complete. 

Info:

$accessType$sideID
Email: $emailAdd
Cell Number: $cellNumber
License Number: $licenseNumber
User Role: $userRole


Result: $accountResult" -button1 "Exit" -button2 "Export")

	#-button1 - Exit
	if [ $buttonClickedResults == 0 ]; then
		exit 0
	else
		touch ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo $accessType$sideID >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo Email: $emailAdd >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo Cell Number: $cellNumber >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo License Number: $licenseNumber >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo User Role: $userRole >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo "" >> ~/Desktop/$emailAdd.txt
		echo Result: $accountResult >> ~/Desktop/$emailAdd.txt
		exit 0
	fi
