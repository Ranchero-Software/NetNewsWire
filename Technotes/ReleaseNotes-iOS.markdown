# iOS Release Notes

### 6.0 TestFlight build 603 - 16 May 2021

Feedly: handle Feedly API change with return value on deleting a folder
NewsBlur: sync no longer includes items marked as hidden on NewsBlur
FreshRSS: form for adding account now suggests endpoing URL
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

