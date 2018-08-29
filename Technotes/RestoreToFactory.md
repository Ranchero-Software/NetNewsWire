# How to Restore to Factory Settings

Here’s how to start over with untouched preferences and default feeds:

1. Quit NetNewsWire if it’s running.

2. Delete the application support folder. On the command line, do: `rm -rf ~/Library/Application\ Support/NetNewsWire/`

3. Delete the preferences. Just deleting the file won’t do the trick — it’s necessary to use the command line. Do: `defaults delete com.ranchero.NetNewsWire` and then `killall cfprefsd`

Launch NetNewsWire. You should have the default feeds, and all preferences should be reset to their default settings.

#### Alternate version

Run the [cleanPrefsAndData](../cleanPrefsAndData) script instead of doing the above manually.
