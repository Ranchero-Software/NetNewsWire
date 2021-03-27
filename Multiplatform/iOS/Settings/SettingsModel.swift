//
//  SettingsModel.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/4/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

class SettingsModel: ObservableObject {
	
	enum HelpSites {
		case netNewsWireHelp, netNewsWire, supportNetNewsWire, github, bugTracker, technotes, netNewsWireSlack, releaseNotes, none
		
		var url: URL? {
			switch self {
			case .netNewsWireHelp:
				return URL(string: "https://netnewswire.com/help/ios/5.0/en/")!
			case .netNewsWire:
				return URL(string: "https://netnewswire.com/")!
			case .supportNetNewsWire:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/blob/main/Technotes/HowToSupportNetNewsWire.markdown")!
			case .github:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire")!
			case .bugTracker:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/issues")!
			case .technotes:
				return URL(string: "https://github.com/brentsimmons/NetNewsWire/tree/main/Technotes")!
			case .netNewsWireSlack:
				return URL(string: "https://netnewswire.com/slack")!
			case .releaseNotes:
				return URL.releaseNotes
			case .none:
				return nil
			}
		}
	}
	
	@Published var presentSheet: Bool = false
	var accounts: [Account] {
		get {
			AccountManager.shared.sortedAccounts
		}
		set {

		}
	}

	var activeAccounts: [Account] {
		get {
			AccountManager.shared.sortedActiveAccounts
		}
		set {
			
		}
	}

	// MARK: Init

	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange), name: .DisplayNameDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidAddAccount), name: .UserDidAddAccount, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDidDeleteAccount), name: .UserDidDeleteAccount, object: nil)
	}

	var selectedWebsite: HelpSites = .none {
		didSet {
			if selectedWebsite == .none {
				presentSheet = false
			} else {
				presentSheet = true
			}
		}
	}

	func refreshAccounts() {
		objectWillChange.self.send()
	}

	// MARK:- Notifications

	@objc func displayNameDidChange() {
		refreshAccounts()
	}

	@objc func userDidAddAccount() {
		refreshAccounts()
	}

	@objc func userDidDeleteAccount() {
		refreshAccounts()
	}
}
