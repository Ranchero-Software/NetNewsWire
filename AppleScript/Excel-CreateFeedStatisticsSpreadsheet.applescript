-- This script creates an Excel spreadsheet with statistics about all the feeds in your NetNewsWire 

-- the exportToExcel() function creats a single line of data in a spreadsheet

to exportToExcel(docname, rowIndex, feedname, numArticles, numStars, numRead)
	tell application "Microsoft Excel"
		tell worksheet 1 of document docname
			set value of cell 1 of row rowIndex to feedname
			set value of cell 2 of row rowIndex to numArticles
			set value of cell 3 of row rowIndex to numStars
			set value of cell 4 of row rowIndex to numRead
		end tell
	end tell
end exportToExcel


-- the script starts here
-- First, we make a new Excel spreadsheet and fill in the column headers

tell application "Microsoft Excel"
	set newdoc to make new document
	tell worksheet 1 of newdoc
		set value of cell 1 of row 1 to "Name of Feed"
		set value of cell 2 of row 1 to "Articles"
		set value of cell 3 of row 1 to "Read"
		set value of cell 4 of row 1 to "Stars"
	end tell
	set docname to name of newdoc
end tell

-- Then we loop though all the feeds of all the accounts
-- for each feed, we calculate how many articles there are, how many are read, and how many are starred
-- then, we send off the information to Excel

set totalFeeds to 0
tell application "NetNewsWire"
	set allAccounts to every account
	repeat with nthAccount in allAccounts
		set allFeeds to every feed of nthAccount
		repeat with nthFeed in allFeeds
			set feedname to name of nthFeed
			set articleCount to count (get every article of nthFeed)
			set readCount to count (get every article of nthFeed where read is true)
			set starCount to count (get every article of nthFeed where starred is true)
			set totalFeeds to totalFeeds + 1
			my exportToExcel(docname, totalFeeds + 1, feedname, articleCount, readCount, starCount)
		end repeat
	end repeat
end tell
