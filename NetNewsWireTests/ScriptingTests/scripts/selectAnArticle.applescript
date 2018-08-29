

property uparrowKeyCode : 126
property downarrowKeyCode : 125
property rightarrowKeyCode : 124
property leftarrowKeyCode : 123

to activateNetNewsWire()
	tell application "NetNewsWire"
		activate
	end tell
end activateNetNewsWire

to multipleKeyCodes(keycode, numberOfKeys)
	tell application "System Events"
		tell process "NetNewsWire"
			repeat numberOfKeys times
				key code keycode
			end repeat
		end tell
	end tell
end multipleKeyCodes

try
    activateNetNewsWire()
	multipleKeyCodes(rightarrowKeyCode, 1)
on error message
	return {test_result:false, script_result:message}
end try

return {test_result:true, script_result:"selected an article"}
