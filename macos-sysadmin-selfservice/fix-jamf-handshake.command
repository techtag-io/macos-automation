-- This is an Apple Script for when the Jamf handshake connection breaks
-- Rather than walking the user through opening terminal and running "sudo jamf policy" along with any other command lines, they simply open this .app in the /Application folder, and it does the rest.
-- Methode:
-- -It asks for user password - then looks for MDM profiles
-- -If no profiles are found, it runs "sudo profiles renew -type enrollment"
-- - - It asks for user password again, and re-enrolls it
-- -If profiles already exist, it runs "sudo jamf policy"
-- -If it works, odds are it fixed the handshake
-- -If it does not work, it then tries "sudo profiles renew -type enrollment"
-- -If that also fails, it displays that both handshake and re enrollment failed

-- How To:
-- - Copy the code below and place it in Script Editor - modify the dialogs if you like
-- - Save it as an .app file
-- - Deploy it to the device via your MDM


-- Script --


-- Display dialog asking for user authentication
set dialogResponse to display dialog "This app requires user authentication to be run. 

ONLY RUN THIS IF DIRECTED BY SIDE IT." buttons {"Continue", "Cancel"} default button "Continue" with icon note

-- Check if the user clicked "Cancel"
if button returned of dialogResponse is "Cancel" then
	-- Exit the script if "Cancel" is pressed
	return
end if

-- Prompt the user to authenticate using Touch ID or password (via sudo)
try
	-- Request the password securely, this will allow for Touch ID or password prompt
	do shell script "echo ' ' | sudo -S -v" with administrator privileges
	
	-- Check for profiles using the `profiles -P` command
	set command to "sudo profiles -P"
	set profilesOutput to do shell script command with administrator privileges
	--display dialog profilesOutput -- uncomment this to show true output
	if profilesOutput contains "There are no configuration profiles installed" then
		-- No profiles found, display dialog and attempt to enroll
		display dialog "There are no profiles installed. Enrolling the device..." buttons {"OK"} default button "OK" with icon caution
		-- Run profiles renew -type enrollment
		do shell script "sudo profiles renew -type enrollment" with administrator privileges
	else
		-- Profiles found, run sudo jamf policy
		display dialog "Profiles found, trying jamf policy." buttons {"OK"} default button "OK" with icon caution
		try
			-- Define the full path to the jamf command
			set jamfPath to "/usr/local/jamf/bin/jamf" -- Replace with the correct path if different
			
			-- Run jamf policy
			do shell script jamfPath & " policy" with administrator privileges
			-- If successful, show success dialog
			display dialog "Hand Shake Worked" buttons {"OK"} default button "OK" with icon note
		on error
			-- If jamf policy fails, attempt to run profiles renew command
			try
				do shell script "sudo profiles renew -type enrollment" with administrator privileges
				-- Show a dialog indicating that the fallback was run successfully
				display dialog "Profiles renewal was executed successfully." buttons {"OK"} default button "OK" with icon caution
			on error errMsg
				-- If profiles renew also fails, show an error dialog
				display dialog "Both Hand Shake and Profiles renewal failed. Error: " & errMsg buttons {"OK"} default button "OK" with icon stop
			end try
		end try
	end if
	
on error errMsg
	-- General error handler for unexpected issues
	display dialog "Failed to authenticate or execute commands. Error: " & errMsg buttons {"OK"} default button "OK" with icon stop
end try
