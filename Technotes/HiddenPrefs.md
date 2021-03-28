# Hidden Preferences

See AppDefaults.swift for the app’s preference keys, including hidden prefs.

Hidden preferences tend to be named for a person:

1. To distinguish them from regular, un-hidden preferences, and
2. So we can remember who asked for them.

#### Main window titles

The main window doesn’t display its title, partly because it looks cooler that way and partly because it’s redundant information.

The downside to this is that title-less windows do not allow the toolbar to show button names on macOS Catalina. (This is an AppKit thing.)

To turn window titles on, set `KafasisTitleMode` to true.

#### Show separators between articles in the timeline

Set `CorreiaSeparators` to true.

#### Double-click a feed in the sidebar to mark it as read

Set `GruberFeedDoubleClickMarkAsRead` to true.
