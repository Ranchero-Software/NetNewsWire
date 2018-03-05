
try
	tell application "Evergreen"
		tell account id "OnMyMac"
			repeat 3 times
				set newFeed to make new feed with data "https://boingboing.net/feed"
				delete newFeed
			end repeat
            
            set newFolder to make new folder with properties {name:"XCTest folder"}
			repeat 3 times
				set newFeed to make new feed in newFolder with data "https://boingboing.net/feed"
				delete newFeed
			end repeat
            delete newFolder

		end tell
 	end tell
    
    
	set test_result to true
	set script_result to "Success"
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:test_result, script_result:script_result}
