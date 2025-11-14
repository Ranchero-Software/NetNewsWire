//
//  HelpURL.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 9/29/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation

enum HelpURL: String {

	case helpHome = "https://netnewswire.com/help/"
	case website = "https://netnewswire.com/"
	case releaseNotes = "https://github.com/Ranchero-Software/NetNewsWire/releases/"
	case howToSupportNetNewsWire = "https://github.com/Ranchero-Software/NetNewsWire/blob/main/Technotes/HowToSupportNetNewsWire.markdown"
	case githubRepo = "https://github.com/Ranchero-Software/NetNewsWire"
	case bugTracker = "https://github.com/Ranchero-Software/NetNewsWire/issues"
	case slack = "https://netnewswire.com/slack"
	case technotes = "https://github.com/Ranchero-Software/NetNewsWire/tree/main/Technotes"
	case privacyPolicy = "https://netnewswire.com/privacypolicy.html"

#if os(macOS)
	@MainActor func open() {
		Browser.open(self.rawValue, inBackground: false)
	}
#endif
}
