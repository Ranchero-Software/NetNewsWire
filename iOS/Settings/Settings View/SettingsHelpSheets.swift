//
//  SettingsHelpSheets.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/11/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

enum HelpSheet: CustomStringConvertible, CaseIterable {
	
	case help, website, releaseNotes, howToSupport, gitHubRepository, bugTracker, technotes, slack
	
	var description: String {
		switch self {
		case .help:
			return NSLocalizedString("NetNewsWire Help", comment: "NetNewsWire Help")
		case .website:
			return NSLocalizedString("Website", comment: "Website")
		case .releaseNotes:
			return NSLocalizedString("Release Notes", comment: "Release Notes")
		case .howToSupport:
			return NSLocalizedString("How to Support NetNewsWire", comment: "How to Support")
		case .gitHubRepository:
			return NSLocalizedString("GitHub Respository", comment: "Github")
		case .bugTracker:
			return NSLocalizedString("Bug Tracker", comment: "Bug Tracker")
		case .technotes:
			return NSLocalizedString("Technotes", comment: "Technotes")
		case .slack:
			return NSLocalizedString("Slack", comment: "Slack")
		}
	}
	
	var url: URL {
		switch self {
		case .help:
			return URL(string: "https://netnewswire.com/help/ios/6.1/en/")!
		case .website:
			return URL(string: "https://netnewswire.com/")!
		case .releaseNotes:
			return URL(string: URL.releaseNotes.absoluteString)!
		case .howToSupport:
			return URL(string: "https://github.com/brentsimmons/NetNewsWire/blob/main/Technotes/HowToSupportNetNewsWire.markdown")!
		case .gitHubRepository:
			return URL(string: "https://github.com/brentsimmons/NetNewsWire")!
		case .bugTracker:
			return URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!
		case .technotes:
			return URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/main/Technotes")!
		case .slack:
			return URL(string: "https://netnewswire.com/slack")!
		}
	}
	
	var systemImage: String {
		switch self {
		case .help:
			return "questionmark.app"
		case .website:
			return "globe"
		case .releaseNotes:
			return "quote.opening"
		case .howToSupport:
			return "person.3.fill"
		case .gitHubRepository:
			return "archivebox"
		case .bugTracker:
			return "ladybug"
		case .technotes:
			return "chevron.left.slash.chevron.right"
		case .slack:
			return "quote.bubble.fill"
		}
	}
}
