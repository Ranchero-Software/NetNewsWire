-- this script just tests that no error was generated from the script
try
	tell application "NetNewsWire"
		opml representation of feed 1 of account 1
	end tell
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:true}
