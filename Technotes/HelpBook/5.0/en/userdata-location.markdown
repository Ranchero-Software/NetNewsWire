@title Where NetNewsWire data is stored

# Where NetNewsWire data is stored

NetNewsWire remembers your feeds and article read status, as well as your account information and preferences. This information is stored in two different locations on your Mac, but separately from the NetNewsWire app.



Preferences file
----------------

Your NetNewsWire preferences file is called `com.ranchero.NetNewsWire-Evergreen.plist`. It’s stored in your account’s Preferences folder, which can be found in the Finder by navigating to:

*Your home folder* › Library › Preferences


### Preferences caching

The contents in the preferences `plist` file are cached by macOS. If you make any changes or delete the file, log out and log back in before relaunching NetNewsWire to make sure the old settings are fully cleared. (Alternatively, if you prefer, you can also run `killall cfprefsd` from Terminal to reload the preferences cache.)



Feeds and accounts data
-----------------------

Information about your subscribed feeds, article read status and accounts (On my Mac and Feedbin) are stored in your account’s Application Support folder. This can be found in the Finder by navigating to:

*Your home folder* › Library › Application Support › NetNewsWire


### Exporting your feeds

If you just want to export your list of subscribed feeds, NetNewsWire [can export an OPML for you](export-opml.html). 



Resetting or removing NetNewsWire
---------------------------------

If you are running into problems while using NetNewsWire, you may want to reset your settings. By removing the files and folders above you can start over again from scratch. 

You may also want to delete these files if you want to completely remove NetNewsWire from your Mac.


### Can’t find the Library folder?

If you can’t see the Library folder in the Finder, you can open it by holding down the Option (⌥) key and clicking **Go → Library**. For more information, see the [Library folder](https://support.apple.com/en-gb/guide/mac-help/aside/mh35934/10.14/mac/10.14) note in the macOS Documentation.