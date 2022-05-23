# iOS Release Notes

### 6.1 TestFlight build 6103 - 25 Jan 2022

* Fixed regression with keyboard shortcuts.
* Fixed crashing bug adding an account.

### 6.1 TestFlight build 6102 - 23 Jan 2022

* Article themes. Several themes ship with the app, and you can create your own. You can change the theme in Preferences.
* Copy URLs using repaired, rather than raw, feed links.
* Disallow creation of iCloud account in the app if iCloud and iCloud Drive aren’t both enabled.
* Fixed bug showing quote tweets that only included an image.
* Video autoplay is now disallowed.
* Article view now supports RTL layout.

### 6.0.1 TestFlight build 608 - 28 Aug 2021

* Fixed our top crashing bug — it could happen when updating a table view

### 6.0.1 TestFlight build 607 - 21 Aug 2021

* Fixed bug where BazQux-synced feeds might stop updating
* Fixed bug where words prepended with $ wouldn’t appear in Twitter feeds
* Fixed bug where newlines would be just a space in Twitter feeds
* Fixed a crashing bug in Twitter rendering
* Fixed bug where hitting b key to open in browser wouldn’t always work
* Fixed a crashing bug due to running code off the main thread that needed to be on the main thread
* Fixed bug where article unread indicator could have wrong alpha in specific circumstances
* Fixed bug using right arrow key to move focus to Article view
* Fixed bug where long press could trigger a crash
* Fixed bug where external URLs in Feedbin feeds might be lost
* Fixed bug where favicons wouldn’t be found when a home page URL has non-ASCII characters
* Fixed bug where iCloud syncing could stop prematurely when the sync database has records not in the local database
* Fixed bug where creating a new folder in iCloud and moving feeds to it wouldn’t sync correctly

### 6.0 TestFlight build 604 - 31 May 2021

* This is a final candidate
* Updated about NetNewsWire section
* Fixed bug where Tweetbot share sheet could be empty
* Feedly: fixed bug where your custom name could get lost after moving a feed to a different folder
* Twitter: fixed bug handling tweets containing characters made up of multiple scalars
* iCloud: added explanation about when sync may be slow

### 6.0 TestFlight build 603 - 16 May 2021

* Feedly: handle Feedly API change with return value on deleting a folder
* NewsBlur: sync no longer includes items marked as hidden on NewsBlur
* FreshRSS: form for adding account now suggests endpoint URL
* FreshRSS: improved the error message for when the API URL can’t be found
* iCloud: retain existing feeds moved to a folder that doesn’t exist yet (sync ordering issue)
* Renamed a Delete Account button to Remove Account
* iCloud: skip displaying an error message on deleting a feed that doesn’t exist in iCloud
* Preferences: Tweaked text explaining Feed Providers
* Feeds list: context menu for smart feeds is back (regression fix)
* Feeds list: all smart feeds remain visible despite Hide Read Feeds setting
* Article view: fixed zoom issue on iPad on rotation
* Article view: fixed bug where mark-read button on toolbar would flash on navigating to an unread article
* Article view: made footnote detection more robust
* Fixed regression on iPad where timeline and article wouldn’t update after the selected feed was deleted
* Sharing: handle feeds where the URL has unencoded space characters (why a feed would do that is beyond our ken)

### 6.0 TestFlight build 602 - 21 April 2021

* Inoreader: don’t call it so often, so we don’t go over the API limits
* Feedly: handle a specific case where Feedly started not returning a value we expected but didn’t actually need (we were reporting it as an error to the user, but it wasn’t)
