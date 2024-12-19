# Mac Release Notes

## 6.1.8b1 build 6132 18 Dec 2024 - branch 6.1.8-mac tag: mac-6.1.8b1

Hopefully fix state restoration bug by building on Xcode 14

## 6.1.7 build 6131 16 Dec 2024 - branch mac-6.1.7 tag: mac-6.1.7-release

Fix bug clearing refresh progress
Fix bandwidth bugs with downloading web pages to find feed icons and favicons
Update default theme with enhancements by John Gruber
Space out requests made to openrss.org
Send user-agent with platform, version, and build to openrss.org (and only to that site)

## 6.1.7b1 build 6130 15 Dec 2024 - branch mac-6.1.7 tag: mac-6.1.7b1

Fix bug clearing refresh progress
Fix bandwidth bugs with downloading web pages to find feed icons and favicons
Update default theme with enhancements by John Gruber
Space out requests made to openrss.org
Send user-agent with platform, version, and build to openrss.org (and only to that site)

## 6.1.6 build 6127 4 Dec 2024 - branch: 6.1.6 tag: mac-6.1.6

Fix bug clearing sync progress for Feedly accounts

## 6.1.5 build 6126 3 Dec 2024 - branch: 6.1.5 tag: mac-6.1.5

Restore toggle sidebar button to toolbar
Add keyboard shortcut for Copy Article URL and Copy External URL menu items
Fix some Applescript support bugs
Add support for 429 responses and Cache-Control header — will use less bandwidth and will be kinder to servers (for On My Mac and iCloud accounts)
Fix a bug with conditional GET support
Support MarsEdit 5 - it will now appear in Share menu
Fix a crashing bug that could happen when adding an account


## 6.1.5b4 build 6125 2 Dec 2024

Make Cache-Control responses persist between runs
Add MarsEdit 5 to Apple events entitlements

## 6.1.5b3 build 6124 30 Nov 2024

Fix bug introduced in previous beta regarding conditional GET info — all back to normal now
Write our own support for Cache-Control response header. Skip downloading a feed when Cache-Control says it’s too soon

## 6.1.5b2 build 6123 29 Nov 2024

Restore toggle sidebar button to toolbar
Add keyboard shortcut for Copy Article URL and Copy External URL menu items
Fix some Applescript bugs
Support MarsEdit 5 - it will now appear in Share menu
Fix a crashing bug that could happen when adding an account
Remove FeedWrangler support code
Fix data race with article status (read/unread and starred/unstarred)
Switch to using built-in URLSession caching — supports Cache-Control response header and other good things — means the app uses less bandwidth and is kinder to the servers it contacts
Add support for handling 429 responses

## 6.1.5b1 build 6121 1 Dec 2023

Add new setting — turn on/off JavaScript for the article pane. It’s on by default, which matches previous behavior. Note that some content — videos and embedded social media posts, for instance — will often require JavaScript to be _on_ in order to work properly. However, for those who want or need greater security and privacy, we’ve made this setting available.

Fix a case where images might not load in the article pane.

## 6.1.4 build 6120 27 June 2023

Same as 6.1.4b1 but as final release.

## 6.1.4b1 build 6119 25 June 2023

Remove Reddit API integration. Remove UI and code for Extensions.

## 6.1.3 build 6118 25 June 2023

Change release notes URL to point to release notes page: https://github.com/Ranchero-Software/NetNewsWire/releases/

### 6.1.3b1 build 6117 18 June 2023

Show Reddit deprecation notice on startup if needed.

## 6.1.2 build 6114 8 Apr 2023

Update default feeds to remove feeds that don’t appear to be active anymore (sadly!).

## 6.1.1 build 6112 13 Mar 2023

Revised Twitter removal warning to not mention any specific month. We’re holding this release until Twitter shuts down free access to its API.

## 6.1.1 build 6111 9 Feb 2023

Same as 6.1.1b4 but with updated build and version number.

### 6.1.1b4 build 6110 9 Feb 2023

Update the Twitter removal warning to say “later in February” instead of “February 9,” since Twitter postponed the removal date to the 13th and might postpone it further.

### 6.1.1b3 build 6109 6 Feb 2023

Update Safari extension icon (credit to Louie Mantia for the new icon)

### 6.1.1b2 build 6108 5 Feb 2023

Remove Twitter integration. On first launch, for people with Twitter feeds, display an alert explaining what happened

Fix a crashing bug that could happen in the sidebar

### 6.1.1b1 build 6107 3 Nov 2022

Fixed a bug that could prevent users from accessing BazQux if an article was missing a field
Fixed an issue that could prevent Feedly users from syncing if they tried to mark too many articles as read at the same time

### 6.1 build 6106 6 April 2022

Small cosmetic change — better alignment for items in General Preferences pane

### 6.1b5 build 6104 3 April 2022

Updated built-in feeds
Building on a new Apple Silicon Mac — testing to make sure all’s well

### 6.1b4 build 6103 27 Feb 2022

Fixed a few font and sizing issues


### 6.1b3 build 6102 - 8 Feb 2022

Two new themes: Hyperlegible and NewsFax
Change in how built-in themes work: they’re part of the app bundle and they’re not copied into the Themes folder. When a built-in theme changes in a new app release, anyone using that new version gets the changes to the built-in theme

### 6.1b2 build 6101 - 17 Jan 2022

Dealt with provisioning profiles, certificates, and IDs. Made notarization service happy.

### 6.1b1 build 6100 - 9 Jan 2022

Article themes. Several themes ship with the app, and you can create your own. You can change the theme in Preferences or by adding the theme switcher to the toolbar.
Copy URLs using repaired, rather than raw, feed links.
Restore article scroll position on relaunching app.
Added Copy Article URL and Copy External URL commands to the Edit menu.
Fixed a bug where using cmd-Q wouldn’t always quit the app as quickly as one might prefer.
Disallow creation of iCloud account in the app if iCloud and iCloud Drive aren’t both enabled.
Fixed bug showing quote tweets that only included an image.
Added a hidden pref to suppress downloading/syncing on start: `defaults write com.ranchero.NetNewsWire-Evergreen DevroeSuppressSyncOnLaunch -bool true`
Video autoplay is now disallowed.
Article view now supports RTL layout.

### 6.0.3b1 build 6033 - 20 May 2021

Feedly: handle API change with deleting and don’t show a spurious error
NewsBlur: don’t fetch articles marked hidden by NewsBlur
FreshRSS: add API endpoint URL example in setup form
iCloud: fixed bug not retaining feeds in a folder where the folder hasn’t been synced yet
Feeds list: smart feeds remain visible despite Hide Read Feeds setting
Keyboard shortcuts: fixed regression where L key wouldn’t go to next unread when feed is all read
Twitter extension: fixed weird bug where an extra https:/ could appear in tweet text

### 6.0.2 build 6032 - 20 April 2021

Same as 6.0.2b1

### 6.0.2b1 build 6031 - 15 April 2021

Inoreader sync: fixed (hopefully) cause of rate limit errors — now doing background sync of statuses much less often - note that this fix needs to be rolled out across all NetNewsWire users in order for it to have full effect
Fixed regression with the L key — now works properly again

### 6.0.1 build 6030 - 1 Apr 2021

Adjusted layout of the add account sheet so that it fits on smaller monitors
Sidebar: properly scale the smart feed icons when sidebar is set to large size in System Preferences

### 6.0.1b2 build 6029 - 29 Mar 2021

Twitter: fixed a date parsing bug that could affect people in some locales, which would prevent Twitter feeds from working for them
Feeds list: fixed bug where newly added feed would be called Untitled past the time when the app actually knows its name
Fixed bug where next-unread command wouldn’t wrap around when you got to the bottom of the Feeds list

### 6.0.1b1 build 6028 - 28 Mar 2021

Timeline: fix bug updating article display when an article with the same article ID appears more than once (which can happen when a person has multiple accounts)
iCloud: won’t add feeds that aren’t parseable, which fixes an error upon trying to rename one of these feeds
Feedbin: fixed a bug with read/unread status syncing

### 6.0 build 6027 - 26 Mar 2021

No code changes since 6.0b5
Changed the feed URL for test builds back to the normal test build feed URL

### 6.0b5 build 6026 - 25 Mar 2021

Fixed a bug where sometimes the app wouldn’t automatically refresh after the Mac wakes from sleep
Updated the Help book link to the 6.0 Mac help book website
App now displays a helpful error message if you don’t have iCloud Drive enabled and were able to successfully add an iCloud Account

### 6.0b4 build 6024 - 23 Mar 2021

Feedly: Deleting a feed successfully no longer shows an alert and leaves the feed in the sidebar
iCloud sync: fixed a bug where, in some circumstances, dragging a feed from elsewhere in the sidebar to the iCloud account could trigger the feed-finder
NetNewsWire will now refresh on launch if you have the Debug menu enabled
Article view: footnotes should now work with articles from a Feedly account

### 6.0b3 build 6023 - 16 Mar 2021

Article view: fixed bug where URL status field might not disappear when switching articles
iCloud sync: dragging feeds from elsewhere in the sidebar to the iCloud account won’t trigger the feed-finding process since this is a better experience for migrating
Syncing: fixed a bug authenticating with some sync services when the user has some special characters in their password
Preferences: removed checkbox for showing unread count in the Dock — control this instead via System Preferences > Notifications > NetNewsWire > Badge app icon


### 6.0b2 build 6022 - 13 Mar 2021

Feeds list: when dragging feeds/folders from one account to another, the operation is now *always* copy, to avoid data loss due to misunderstanding that moving a feed between accounts does not move its read/starred statuses
iCloud sync: refined logic to improve performance of large uploads
Fixed a crashing bug that could happen when deleting an iCloud-synced folder
Fixed a crashing bug, triggered by bad server data, that could happen when validating credentials with syncing systems that use the Reader API

### 6.0b1 build 6012 - 7 Mar 2021

Article view: fixed several layout edge cases, including with fullscreen
Timeline: fixed a bug scrolling up via arrow key where a row might not be fully visible when it should be

### 6.0a6 build 6011 - 6 Mar 2021

Article view: make code and preformatted fonts and sizes follow Apple’s precedents more closely
Article view: removed a stray line next to the timeline/article separator
Debug menu: add Force Crash command (beware: works in production)
Debug menu: allow Test Crash Log Sender to work in production

### 6.0a5 build 6010 - 3 Mar 2021

Performance boost: use compression with content synced in CloudKit
Fixed bug where detail view title bar could be overlapped by toolbar when in full screen
Fixed bug where add-feed window could block when syncing CloudKit statuses
Added hidden pref to mark all as read in a feed when double-clicking on it in the sidebar and opening its home page (defaults write com.ranchero.NetNewsWire-Evergreen GruberFeedDoubleClickMarkAsRead -bool true)
Switched the crash log catcher URL to our brand-new crash log catcher server

### 6.0a4 build 6009 - 22 Feb 2021

Fix a bug with keyboard shortcuts on Big Sur (for real this time)
Change drag-and-drop behavior to default to copy when dragging between accounts
Show a single error message when dragging feeds into an account and some of the feeds can’t be found

### 6.0a3 build 6008 - 21 Feb 2021

Use the new URL for the crash report catcher (so that we actually get crash logs again)
Update other URLs to point to netnewswire.com when correct
Fix a bug with keyboard shortcuts on Big Sur
Show folders more quickly in the iCloud account when dragging a folder into that account

### 6.0a2 build 6007 - 6 Feb 2021

Fix regression in Preferences toolbar (placement of icons was wrong on Big Sur)
Fix regression in Twitter support (it wasn’t working)

### 6.0a1 build 6006 - 4 Feb 2021

Feeds list: added contextual menu items for always showing reader view and for notifications
Feeds list: now respects the size chosen in System Preferences > General > Sidebar icon size
iCloud syncing: don’t inadvertently clear progress indicator when copying a folder and an error was encountered
Notifications: don’t open app when closing a notification

### 6.0d5 build 6005 - 22 Jan 2021

Added some shadow to the app icon
Fixed bug where iCloud account description was truncated in Catalina, in account setup
Fixed bug with iCloud account where undoing deletes of read feeds left articles deleted
Fixed bug connecting to Inoreader when username has a + character
Fixed bug with NewsBlur when all feeds are in folders
Fixed long beachball on quit that could happen with the iCloud account (due to a long sync)

### 6.0d4 build 6004 - 16 Jan 2021

* Big Sur app icon
* Big Sur UI (when running on Big Sur)
* App is now sandboxed
* Syncing via iCloud
* Syncing via BazQux, Inoreader, NewsBlur, The Old Reader, and FreshRSS
* Special support for Twitter and Reddit feeds
* Share extension, so you can send URLs to NetNewsWire
* Preference to change article text size
* Preference to set preferred browser
* External link, when available, shows in article view
* High resolution icons in the sidebar (when available)

## 5.1.3 build 3018 - 9 Nov 2020

* Fixed a crashing bug that could happen with empty titles in the timeline
* Fixed a crashing bug that could happen when adding a feed

### 5.1.3b1 build 3017 - 6 Nov 2020

* Fixed a crashing bug that could happen with empty titles in the timeline
* Fixed a crashing bug that could happen when adding a feed

## 5.1.2 build 3016 - 31 Oct 2020

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

