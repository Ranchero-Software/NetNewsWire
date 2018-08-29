-- this script sets up NetNewsWire so it is ready to be tested
-- to get a current article

to activateNetNewsWire()
	tell application "NetNewsWire"
		activate
	end tell
end activateNetNewsWire

tell application "System Events"
	set isFrontmost to frontmost of process "NetNewsWire"
	repeat while isFrontmost is false
		my activateNetNewsWire()
		set isFrontmost to frontmost of process "NetNewsWire"
	end repeat
end tell

return {test_result:true, script_result:"finished"}
