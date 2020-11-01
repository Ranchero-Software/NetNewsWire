# Mac Release Notes

## 5.1.2 build 3016 - 31 Oct 2010

* Fixed a crashing bug in the timeline
* Fixed a background color bug in dark mode in the timeline
* Fixed a crashing bug updating the browser popup in Preferences
* Feedbin: fixed bug where credentials couldn’t be updated
* Feedly: fixed bug syncing feed name changes
* Feedly: fixed a bug adding a feed to a Feedly collection that has a + in its name
* On My Mac: increased performance downloading feeds in the On My Mac account

### 5.1.2b3 build 3015 - 29 Oct 2020

* Fixed bug where Feedbin credentials couldn’t be updated

### 5.1.2b2 build 3014 - 26 Oct 2020

* Fixed a crashing bug in the timeline
* Fixed a background color bug in dark mode in the timeline
* Fixed a crashing bug updating the browser popup in Preferences
* Feedly: fixed bug syncing feed name changes

### 5.1.2b1 build 3013 - 17 Oct 2020

* Increased performance downloading feeds in the On My Mac account
* Fixed a bug adding a feed to a Feedly collection that has a + in its name

## 5.1.1 build 3012 - 5 Oct 2020

* Preferences: restored ability to set default RSS reader
* Fixed bug where o key wouldn’t mark older as read
* Fixed a crash in the code that handles URLs with non-ASCII characters
* Fixed an Open System Preferences button in an alert that didn’t work
* Fixed a crash handling a specific type of really weird URL
* Fixed a possible hang when adding a feed to Feedly (and the feed isn’t found)
* Fixed some UI issues to do with adding a Feedly account
* Fixed contrast in footnotes indicator
* Fixed bug where duplicate accounts (same username and service) could be made
* Fixed bug where open in Safari in background might not open in the background

### 5.1.1a2 build 3011 - 1 Oct 2020

* Fixed a crash handling a specific type of really weird URL
* Fixed a possible hang when adding a feed to Feedly (and the feed isn’t found)
* Fixed some UI issues to do with adding a Feedly account
* Fixed contrast in footnotes indicator
* Fixed bug where duplicate accounts (same username and service) could be made
* Fixed bug where open in Safari in background might not open in the background

### 5.1.1a1 build 3010 - 22 Sep 2020

* Preferences: restored ability to set default RSS reader
* Fixed bug where o key wouldn’t mark older as read
* Fixed a crash in the code that handles URLs with non-ASCII characters
* Fixed an Open System Preferences button in an alert that didn’t work

### 5.1b2 build 3005 - 8 Sep 2020

* Articles with non-ASCII URLs can now open in browser
* Adding feeds with non-ASCII URLs now works
* Feeds view, timeline: fixed bug where multiple selection could result in showing only unread articles
* Help menu: NetNewsWire Help now links to the 5.1 help book
* Inspector: window title now matches name of thing being inspected
* VoiceOver: fix bug navigating into the Add Account table
* Fixed crash that could happen when adding an account
* Preferences: Removed non-working (due to sandboxing) feature for setting the default RSS reader

### 5.1a2 build 3004 - 1 Sep 2020

* Feeds view: fixed bug where unread counts might be misplaced at startup
* Timeline: fixed extra row of pixels in swipe actions
* Article view: tweaked some colors
* Toolbar: reader view button is now not blurry on non-retina machines
* Toolbar: review view animation looping fixed
* Inspector: fixed some layout/spacing issues
* Preferences: tweaked text relating to holding down the shift key
* Dock unread count: now asks for permission so it can show it

### 5.1d3 build 3003 - 20 Aug 2020

* Feedly syncing
* Reader view
* Notifications (configure per feed in the Info window)
* Sandboxing
* Multiple windows - File > New Window
* View > Hide Read Feeds
* View > Hide Read Articles (also a filter button above timeline for this)
* Clean Up command (to immediately hide read articles when hide-read-articles is on)
* Feeds view: remember expansion state between runs
* Timeline: more compact rows (source and date on same line)
* Timeline: sort menu on top
* Timeline: swipe actions
* Article view: shift-space scrolls backwards
* AppleScript: article now has a feed property
* Hold down shift to temporarily toggle open-in-browser in background preference
* Article > Mark Above as Read, Mark Below as Read
* Choose preferred browser (for viewing web pages)

## 5.0.4 build 2622 - 8 Aug 2020

* Performance enhancement: fetching articles is faster and uses less memory
* Changed the retention policy to match iOS
* Feeds view: fixed bug where multiple sequential deletes could mess up the current selection index
* Article view: dealt with Twitter change that caused Twitter embeds to get cut off
* Article view: properly size emojis that are actually graphics (from Wordpress, for instance)
* Article view: stop playing any audio if the window is closed
* Article view: don’t let line lengths get too long
* Article view: fixed display of BandCamp widgets
* OPML export: use an accessory view instead of an intermediate sheet
* Add Folder: disable Add Folder button when text field is empty
* Feed icons: get more icons from Feedbin; get favicons from some tricky cases
* Add Feed: now allows IPv6 literal URLs
* Feed discovery: give less weight to feeds with the word “podcast” in them, because they’re probably not what we want
* Refreshing: fixed bug where automatic refreshing might not happening after the computer wakes from sleep
* Preferences > Accounts: Renamed “Create” account button to “Add Account”
* Fixed bug where a Feedbin article could stay unread right after you select it
* Fixed bug where folder names with double quotes would have the quotes replaced with the HTML entity for quote
* When importing from NNW 3, the app now ignores script feeds (since we don’t have that feature yet)
* Fixed bug where, right after initial launch, the spacebar might not work to go to next unread article
* Pressing return now opens the selected article in your browser

### 5.0.4b1 build 2621 - 3 Aug 2020

* Changed the retention policy to match iOS
* Performance enhancement: fetching articles is faster and uses less memory

### 5.0.4d2 build 2620 - 9 July 2020

* Feeds view: fixed bug where multiple sequential deletes could mess up the current selection index
* Article view: dealt with Twitter change that caused Twitter embeds to get cut off
* Article view: properly size emojis that are actually graphics (from Wordpress, for instance)
* Article view: stop playing any audio if the window is closed
* Article view: don’t let line lengths get too long
* Article view: fixed display of BandCamp widgets
* OPML export: use an accessory view instead of an intermediate sheet
* Add Folder: disable Add Folder button when text field is empty
* Feed icons: get more icons from Feedbin; get favicons from some tricky cases
* Add Feed: now allows IPv6 literal URLs
* Feed discovery: give less weight to feeds with the word “podcast” in them, because they’re probably not what we want
* Refreshing: fixed bug where automatic refreshing might not happening after the computer wakes from sleep
* Preferences > Accounts: Renamed “Create” account button to “Add Account”
* Fixed bug where a Feedbin article could stay unread right after you select it
* Fixed bug where folder names with double quotes would have the quotes replaced with the HTML entity for quote
* When importing from NNW 3, the app now ignores script feeds (since we don’t have that feature yet)
* Fixed bug where, right after initial launch, the spacebar might not work to go to next unread article
* Pressing return now opens the selected article in your browser

