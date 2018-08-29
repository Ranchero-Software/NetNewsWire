try
    tell application "NetNewsWire"
	    open location "http://scripting.com/rss"
    end tell
on error message
    return {test_result:false, script_result:message}
end

-- open location is not expected to return a value
-- trying to access result should trigger an error, and that indicates a successful test

try
	set getURLResult to the result
	set testResult to false
on error message
	set testResult to true
end try

return {test_result:testResult}
