-- this script   tests that it is possible to get the url property of the current article
-- it uses system event accessibility scripting to set up the main window
-- one needs to authorize scripting accessibility control in the System Preferences'
--  Privacy and security pane

try
    tell application "NetNewsWire"
        {url, permalink, external url} of current article
    end tell
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:true, script_result:"tests passed"}
