-- this script sets up Evergreen so it is ready to be tested
-- to get a current article

to activateEvergreen()
	tell application "Evergreen"
		activate
	end tell
end activateEvergreen

tell application "System Events"
	set isFrontmost to frontmost of process "Evergreen"
	repeat while isFrontmost is false
		my activateEvergreen()
		set isFrontmost to frontmost of process "Evergreen"
	end repeat
end tell

return {test_result:true, script_result:"finished"}
