property uparrowKeyCode : 126
property downarrowKeyCode : 125
property rightarrowKeyCode : 124
property leftarrowKeyCode : 123

to activateEvergreen()
	tell application "Evergreen"
		activate
	end tell
end activateEvergreen

to multipleKeyCodes(keycode, numberOfKeys)
	tell application "System Events"
		tell process "Evergreen"
			repeat numberOfKeys times
				key code keycode
			end repeat
		end tell
	end tell
end multipleKeyCodes

to establishMainWindowStartingState()
	activateEvergreen()
	multipleKeyCodes(downarrowKeyCode, 2)
	multipleKeyCodes(rightarrowKeyCode, 2)
	multipleKeyCodes(leftarrowKeyCode, 2)
	multipleKeyCodes(uparrowKeyCode, 50)
end establishMainWindowStartingState

try
	establishMainWindowStartingState()
	-- hit the down arrow a few times to get into the feeds
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:true, script_result:"established starting state"}
