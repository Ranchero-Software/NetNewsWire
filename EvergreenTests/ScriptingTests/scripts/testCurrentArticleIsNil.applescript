-- this script   tests that it is possible to get the url property of the current article
-- it uses system event accessibility scripting to set up the main window
-- one needs to authorize scripting accessibility control in the System Preferences'
--  Privacy and security pane

try
    tell application "Evergreen"
        set shouldBeMissingValue to current article
    end tell

    --verify that the current article is in fact 'missing vcalue'
    if shouldBeMissingValue is missing value then
        set the_message to "passed tests"
        set the_result to true
    else
        set the_message to "expected current article to be 'missing value'"
        set the_result to false
    end if
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:the_result, script_result:the_message}
