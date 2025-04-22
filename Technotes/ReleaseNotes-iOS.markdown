# iOS Release Notes

### 6.1.9 TestFlight build 6190 22 April 2025 — branch: main tag: iOS-6.1.9-6190

Made some external modules internal to the app (RSCore, RSParser).
Added .xctestplan files.

### 6.1.8 TestFlight build 6146 21 Jan 2025 - branch: 6.1.8-ios tag: iOS-6.1.8-6146

Fixed a bug where sometimes feed icons wouldn’t show up until switching screens
Fixed crash in the starred articles widget

### 6.1.8 TestFlight build 6145 18 Jan 2025 - branch: 6.1.8-ios tag: iOS-6.1.8-6145

Improved usability of split view in iPad
Fixed bug where you could get two refresh progress bars at the same time on iPad (one in feeds view toolbar and one in timeline view toolbar)

### 6.1.7 TestFlight build 6144 12 Jan 2025 - branch: 6.1.7-ios tag: iOS-6.1.7-6144

Fix crash on rotation on Max phone when in fullscreen and going from portrait to landscape
Improve the look of tables in the default article theme

### 6.1.7 TestFlight build 6143 11 Jan 2025 - branch: 6.1.7-ios tag: iOS-6.1.7-6143

Made the split view on iPad less obtrusive and hard to use in portrait view
Fixed bug where controls could disappear when not in fullscreen mode

## 6.1.6 App Store build 6142 6 Jan 2025 - branch: 6.1.6-ios tag: iOS-6.1.6-6142

(Releasing build 6142 as App Store release)

Fix a crashing bug that would most commonly appear on closing a web page
Fix weird border issues with widgets
Fix bug updating account and feed names on Feeds screen after names have been edited
Fix a bug where some feeds can be slow to update (drop Cache-Control support except for openrss.org)
Fix display bug with footnote links (remove link underline)
Adopt modern iOS split view

### 6.1.6 TestFlight build 6142 2 Jan 2025 - branch: 6.1.6-ios tag: iOS-6.1.6-6142

Fix a bug where some feeds can be slow to update. (Technical change: drop Cache-Control support except for openrss.org, which requested the support in the first place. Most feed providers aren’t providing intentional Cache-Control headers, it appears, and our continuing Cache-Control support means too-long delays between feed updates in many cases.)

### 6.1.6 TestFlight build 6141 1 Jan 2025 - branch: 6.1.6-ios tag: iOS-6.1.6-6141

Fix bug updating account and feed names on Feeds screen after names have been edited
Fix Go To Feed menu item bug

### 6.1.6 TestFlight build 6140 31 Dec 2024 - branch: 6.1.6-ios tag: iOS-6.1.6-6140

Fix theme importing
Draw account row separators on the Feeds view all the way across the screen

### 6.1.6 TestFlight build 6139 30 Dec 2024 - branch: 6.1.6-ios tag: iOS-6.1.6-6139

Fix display bug with footnote links (remove link underline)
Fix bug with toolbars appearing when fullscreen mode is on
Fix crashing bug on the Settings > Timeline layout view
Make sure Feeds view shows on first run
Add button to articles view that shows/hides timeline when in regular horizontal size class (iPads, mainly)

### 6.1.6 TestFlight build 6138 26 Dec 2024 - branch: 6.1.6-ios tag: iOS-6.1.6-6138

Fix layout issues with widgets — adopt widget API changes from iOS 17

### 6.1.6 TestFlight build 6137 23 Dec 2024 - branch: 6.1.6-ios tag: iOS-6.1.6-6137

Fix bug where next-unread on iPhone would sometimes briefly show the timeline before going to the next article

### 6.1.6 TestFlight build 6136 22 Dec 2024 - branch: 6.1.6-ios tag: iOS-6.1.6-6136

Hopefully fix layoutSubviews crash by switching to the modern three-column split view

### 6.1.5 TestFlight build 6135 16 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6135

Add dark and tinted app icons

### 6.1.5 TestFlight build 6134 15 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6134

Fix crash introduced in previous build (crash on selecting a folder)

### 6.1.5 TestFlight build 6133 14 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6133

Fix bandwidth-use bugs with downloading feed home pages to find feed icons and favicons
Update default theme with enhancements by John Gruber

### 6.1.5 TestFlight build 6132 12 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6132

Restore ability to swipe back from a Safari view (web page view)
Space out requests made to openrss.org
Send user-agent with platform, version, and build to openrss.org (and only to that site)
Cut down on bandwidth use on fetching web page metadata (still more work to do on this one, but this is an improvement)

### 6.1.5 TestFlight build 6131 10 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6131

Fix hanging progress indicator in the Feeds view

### 6.1.5 TestFlight build 6130 9 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6130

Fix crash importing OPML subscriptions

### 6.1.5 TestFlight build 6129 8 Dec 2024 - branch: 6.1.5 tag: iOS-6.1.5-6129

Fix newly-introduced bugs with reporting refresh/sync progress

### 6.1.5 TestFlight build 6128 - 7 Dec 2024

Restore ability to tap on image and view its alt text (as with xkcd, for instance)

### 6.1.5 TestFlight build 6127 - 7 Dec 2024

Fix a crashing bug in `-[UINavigationBar layoutSubviews:]` that started when we built with Xcode 15
Now building with Xcode 16.1

### 6.1.5 TestFlight build 6126 - 4 Dec 2024

Use less bandwidth by respecting Cache-Control headers — skip refreshing feeds that have asked not to be refreshed yet. (This is of course also kind to servers, which is important.)
Fix a potential crashing bug (data race) in the object that stores article status (read/unread, starred/unstarred)

### 6.1.5 TestFlight build 6125 - 4 Dec 2024

Use less bandwidth by respecting Cache-Control headers — skip refreshing feeds that have asked not to be refreshed yet. (This is of course also kind to servers, which is important.)
Fix a potential crashing bug (data race) in the object that stores article status (read/unread, starred/unstarred)

### 6.1.5 TestFlight build 6124 - 21 Mar 2024

Nothing actually changed — this is just because TestFlight expired.

### 6.1.5 TestFlight build 6123 - 21 Dec 2023

Building with Xcode 14.2 on macOS 13 to see if that makes the new-in-iOS-17 crashing bug go away.

### 6.1.5 TestFlight build 6122 - 19 Dec 2023

Remove code for showing Twitter and Reddit deprecation alerts.

Build using Xcode 15.1.

### 6.1.5 TestFlight build 6121 - 29 Sep 2023

Build using Xcode 15 to make sure there are no regressions.

### 6.1.4 TestFlight build 6120 - 1 July 2023

Build using Xcode 14.3.1 so the app won’t crash on launch on iOS 13.

### 6.1.4 TestFlight build 6119 - 30 June 2023

Remove Reddit from Settings. Remove Reddit API code.

### 6.1.3 TestFlight build 6118 - 23 June 2023

Fix release notes URL: it’s now https://github.com/Ranchero-Software/NetNewsWire/releases/

This build was released to the App Store.

### 6.1.3 TestFlight build 6117 - 18 June 2023

Show Reddit shutoff alert to people using Reddit integration.

### 6.1.2 TestFlight build 6116 - 19 Mar 2023

Revise Twitter alert to not mention any dates
Update copyright to 2023

### 6.1.1 TestFlight build 6114 - 5 Feb 2023

Remove Twitter integration. Include alert that Twitter integration was removed.

### 6.1.1 TestFlight build 6113 - 22 Jan 2023

Fix a crashing bug when fetching data for the widget

### 6.1.1 TestFlight build 6112 - 16 Jan 2023

Add some feeds back to defaults — now an even 10 feeds

### 6.1.1 TestFlight build 6111 - 8 Jan 2023 (didn’t actually go out via TestFlight)

Fixed a crashing bug in the Feeds screen
Cut way down on number of default feeds, added BBC World News

## 6.1 Release build 6110 - 9 Nov 2022

Changes since 6.0.1…

Article themes. Several themes ship with the app, and you can create your own. You can change the theme in Preferences.
Fixed a bug that could prevent BazQux syncing when an article may not contain all the info we expect
Fixed a bug that could prevent Feedly syncing when marking a large number of articles as read
Disallow creation of iCloud account in the app if iCloud and iCloud Drive aren’t both enabled
Added links to iCloud Syncing Limitations & Solutions on iCloud Account Management UI
Copy URLs using repaired, rather than raw, feed links
Fixed bug showing quote tweets that only included an image
Video autoplay is now disallowed
Article view now supports RTL layout
Fixed a few crashing bugs
Fixed a layout bug that could happen on returning to the Feeds list
Fixed a bug where go-to-feed might not properly expand disclosure triangles
Prevented the Delete option from showing in the Edit menu on the Article View
Fixed Widget article icon lookup bug


### 6.1 TestFlight build 6109 - 31 Oct 2022

Enhanced Widget integration to make counts more accurate
Enhanced Widget integration to make make it more efficient and save on battery life

### 6.1 TestFlight build 6108 - 28 Oct 2022

Fixed a bug that could prevent BazQux syncing when an article may not contain all the info we expect
Fixed a bug that could prevent Feedly syncing when marking a large number of articles as read
Prevent Widget integration from running while in the background to remove some crashes

### 6.1 TestFlight build 6107 - 28 Sept 2022

Added links to iCloud Syncing Limitations & Solutions on iCloud Account Management UI
Prevented the Delete option from showing in the Edit menu on the Article View
Greatly reduced the possibility of a background crash caused by Widget integration
Fixed Widget article icon lookup bug

### 6.1 TestFlight build 6106 - 9 July 2022

Fix a bug where images wouldn’t appear in the widget

### 6.1 TestFlight build 6105 - 6 July 2022

Write widget icons to the shared container
Make crashes slightly less likely when building up widget data

### 6.1 TestFlight build 6104 - 6 April 2022

Building on a new machine and making sure all’s well
Moved built-in themes to the app bundle so they’re always up to date
Fixed a crash in the Feeds list related to updating the feed image
Fixed a layout bug that could happen on returning to the Feeds list
Fixed a bug where go-to-feed might not properly expand disclosure triangles

### 6.1 TestFlight build 6103 - 25 Jan 2022

Fixed regression with keyboard shortcuts.
Fixed crashing bug adding an account.

### 6.1 TestFlight build 6102 - 23 Jan 2022

Article themes. Several themes ship with the app, and you can create your own. You can change the theme in Preferences.
Copy URLs using repaired, rather than raw, feed links.
Disallow creation of iCloud account in the app if iCloud and iCloud Drive aren’t both enabled.
Fixed bug showing quote tweets that only included an image.
Video autoplay is now disallowed.
Article view now supports RTL layout.### 6.0.1 TestFlight build 608 - 28 Aug 2021

Fixed our top crashing bug — it could happen when updating a table view

### 6.0.1 TestFlight build 607 - 21 Aug 2021

Fixed bug where BazQux-synced feeds might stop updating
Fixed bug where words prepended with $ wouldn’t appear in Twitter feeds
Fixed bug where newlines would be just a space in Twitter feeds
Fixed a crashing bug in Twitter rendering
Fixed bug where hitting b key to open in browser wouldn’t always work
Fixed a crashing bug due to running code off the main thread that needed to be on the main thread
Fixed bug where article unread indicator could have wrong alpha in specific circumstances
Fixed bug using right arrow key to move focus to Article view
Fixed bug where long press could trigger a crash
Fixed bug where external URLs in Feedbin feeds might be lost
Fixed bug where favicons wouldn’t be found when a home page URL has non-ASCII characters
Fixed bug where iCloud syncing could stop prematurely when the sync database has records not in the local database
Fixed bug where creating a new folder in iCloud and moving feeds to it wouldn’t sync correctly


### 6.0 TestFlight build 604 - 31 May 2021

This is a final candidate
Updated about NetNewsWire section
Fixed bug where Tweetbot share sheet could be empty
Feedly: fixed bug where your custom name could get lost after moving a feed to a different folder
Twitter: fixed bug handling tweets containing characters made up of multiple scalars
iCloud: added explanation about when sync may be slow

### 6.0 TestFlight build 603 - 16 May 2021

Feedly: handle Feedly API change with return value on deleting a folder
NewsBlur: sync no longer includes items marked as hidden on NewsBlur
FreshRSS: form for adding account now suggests endpoint URL
FreshRSS: improved the error message for when the API URL can’t be found
iCloud: retain existing feeds moved to a folder that doesn’t exist yet (sync ordering issue)
Renamed a Delete Account button to Remove Account
iCloud: skip displaying an error message on deleting a feed that doesn’t exist in iCloud
Preferences: Tweaked text explaining Feed Providers
Feeds list: context menu for smart feeds is back (regression fix)
Feeds list: all smart feeds remain visible despite Hide Read Feeds setting
Article view: fixed zoom issue on iPad on rotation
Article view: fixed bug where mark-read button on toolbar would flash on navigating to an unread article
Article view: made footnote detection more robust
Fixed regression on iPad where timeline and article wouldn’t update after the selected feed was deleted
Sharing: handle feeds where the URL has unencoded space characters (why a feed would do that is beyond our ken)

### 6.0 TestFlight build 602 - 21 April 2021

Inoreader: don’t call it so often, so we don’t go over the API limits
Feedly: handle a specific case where Feedly started not returning a value we expected but didn’t actually need (we were reporting it as an error to the user, but it wasn’t)

