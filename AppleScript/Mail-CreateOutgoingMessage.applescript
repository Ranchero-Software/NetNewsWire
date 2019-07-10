-- This script grabs the current article in NetNewsWire and copies relevant information about it 
--    to a new outgoing message in Mail
-- the intended use is that the user wants to send email about the current article, and 
--    would fill in the recipient and then send the message

-- sometimes, an article has contents, and sometimes it has html contents
-- this function getContentsOrHtml() gets the contents as text, despite the representation
-- first it checks to see if there are plain text contents
-- if not, it looks for html contents, and converts those to plain text using a shell script that invokes textutil
-- if it can't find either plain text or html, it returns "couldn't find article text"
to getContentsOrHtml()
	tell application "NetNewsWire"
		set textContents to the contents of the current article
		if textContents is not "" then
			return textContents
		else
			set htmlContents to html of the current article
			if htmlContents is not "" then
				set shellScript to " echo '" & htmlContents & "' | /usr/bin/textutil -stdin -stdout -format html -convert txt"
				set pureText to do shell script shellScript
				return pureText
			end if
		end if
	end tell
	return "couldn't find article text"
end getContentsOrHtml


-- given a list of author names, generate a happily formatted list like "Jean MacDonald and James Dempsey"
-- if the list is more than two names, use Oxford comma structure: "Brent Simmons, Jean MacDonald, and James Dempsey"

to formatListOfNames(listOfNames)
	set c to count listOfNames
	if c is 1 then
		set formattedList to item 1 of listOfNames
	else if c is 2 then
		set formattedList to item 1 of listOfNames & " and " & item 2 of listOfNames
	else
		set frontOfList to items 1 thru (c - 1) of listOfNames
		set lastName to item c of listOfNames
		set tid to AppleScript's text item delimiters
		set AppleScript's text item delimiters to ", "
		set t1 to frontOfList as text
		set formattedList to t1 & ", and " & lastName
		set AppleScript's text item delimiters to tid
	end if
	return formattedList
end formatListOfNames


-- sometimes, an article has an author, sometimes it has more than one, sometimes there's no author
-- this function getAuthorStub() returns a string like " from Jean MacDonald "  that can be used in crafting a message
-- about the current article.  If there are no authors, it just returns a single space.
to getAuthorStub(authorNames)
	try
		if ((count authorNames) is greater than 0) then
			return " from " & formatListOfNames(authorNames) & " "
		end if
	end try
	return " "
end getAuthorStub



-- Here's where the script starts

-- first, get some relevant info out for NetNewsWire
tell application "NetNewsWire"
	set articleUrl to the url of the current article
	set articleTitle to the title of the current article
	set authorNames to name of authors of the current article
end tell


-- then, prepare the message subject and message contents
set messageSubject to "From NetNewsWire to you: " & articleTitle
set myIntro to "Here's something" & getAuthorStub(authorNames) & "that I was reading on NetNewsWire: "
set messageContents to myIntro & return & return & articleUrl & return & return & getContentsOrHtml()


-- lastly, make a new outgoing message in Mail with the given subject and contents
tell application "Mail"
	set m1 to make new outgoing message with properties {subject:messageSubject}
	set content of m1 to messageContents
end tell