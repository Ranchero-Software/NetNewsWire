-- this script just tests that no error was generated from the script
--  and that the returned list is greater than 0
try
	tell application "NetNewsWire"
		set namesResult to name of every author of every feed of every account
	end tell
	set test_result to ((count items of namesResult) > 0)
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:test_result}
