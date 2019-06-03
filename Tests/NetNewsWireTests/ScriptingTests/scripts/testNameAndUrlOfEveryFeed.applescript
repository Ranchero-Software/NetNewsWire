-- this script just tests that no error was generated from the script
try
	tell application "NetNewsWire"
		{name, url} of every feed of every account
	end tell
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:true}
