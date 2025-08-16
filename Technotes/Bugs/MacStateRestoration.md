# Mac State Restoration

https://github.com/Ranchero-Software/NetNewsWire/issues/4589

https://github.com/Ranchero-Software/NetNewsWire/issues/4631

## State to restore

Hide Read Articles
Hide Read Feeds
Windows positions, including split view positions

## Warnings

	WARNING: Secure coding is automatically enabled for restorable state! However, not on all supported macOS versions of this application. Opt-in to secure coding explicitly by implementing NSApplicationDelegate.applicationSupportsSecureRestorableState:.

## How state restoration works according to Apple

Info.plist: NSApplicationSupportsRestorableState - true

NSUserInterfaceItemIdentification

NSWindowRestoration Protocol
window.restorationClass = …

encodeRestorableStateWithCoder:
restoreStateWithCoder:

self.restorationIdentifier = "MainWindowController"

AppDelegate — application:shouldRestoreApplicationState: and application:shouldSaveApplicationState: for complex cases

Can be turned on and off via system pref

## Tests

Window 1
Restore position — yes
Restore split view position — sometimes
Restore timeline position — no
Restore Hide Read Feeds — yes
Restore Hide Read Articles for inessential — yes

Window 2
Restore position
Restore split view position
Restore Hide Read Feeds
Restore Hide Read Articles for The Verge

Restores second window but not first

With state restoration enabled, all three windows appear, but with not everything restored

---

Close windows tests

1 window
detail scroll not restored
