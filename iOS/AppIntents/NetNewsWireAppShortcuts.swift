//
//  NetNewsWireAppShortcuts.swift
//  NetNewsWire-iOS
//
//  Makes App Intents available in the Shortcuts app / Spotlight / Siri with no user setup.
//  <https://github.com/Ranchero-Software/NetNewsWire/issues/5248>
//

import AppIntents

struct NetNewsWireAppShortcuts: AppShortcutsProvider {

	static var appShortcuts: [AppShortcut] {
		AppShortcut(
			intent: AddFeedAppIntent(),
			phrases: [
				"Add a feed to \(.applicationName)",
				"Add feed in \(.applicationName)"
			],
			shortTitle: "Add Feed",
			systemImageName: "plus"
		)
	}
}
