-- This script creates a new Safari window with all the starred articles in a NetNewsWire instance, each in its own tab

-- declare the safariWindow property here so we can use is throughout the whole script

property safariWindow : missing value

-- the openTabInSafari() function opens a new tab in the appropriate window

to openTabInSafari(theUrl)
	tell application "Safari"
		-- test if this is the first call to openTabInSafari()
		if (my safariWindow is missing value) then
			-- first time through, make a new window with the given url in the only tab
			set newdoc to make new document at front with properties {URL:theUrl}
			-- because we created the doucument "at front", we know it is window 1
			set safariWindow to window 1
		else
			-- after the first time, make a new tab in the wndow we created the first tim
			tell safariWindow
				make new tab with properties {URL:theUrl}
			end tell
		end if
	end tell
end openTabInSafari


-- the script starts here
-- First, initialize safariWindow to be missing value, so that the first time through 
-- openTabInSafari() we'll make a new window to hold all our articles

set safariWindow to missing value


-- Then we loop though all the feeds of all the accounts
-- for each feed, we find all the starred articles
--for each one of those, open a new tab in Safari

tell application "NetNewsWire"
	set allAccounts to every account
	repeat with nthAccount in allAccounts
		set allFeeds to every webFeed of nthAccount
		repeat with nthFeed in allFeeds
			set starredArticles to (get every article of nthFeed where starred is true)
			repeat with nthArticle in starredArticles
				my openTabInSafari(url of nthArticle)
			end repeat
		end repeat
	end repeat
end tell
