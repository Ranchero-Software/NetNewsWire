//
//  SettingsViewModel.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 6/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import SwiftUI
import Combine
import Account

class SettingsViewModel: BindableObject {
	
	let didChange = PassthroughSubject<SettingsViewModel, Never>()
	
	init() {
		NotificationCenter.default.addObserver(self, selector: #selector(accountsDidChange(_:)), name: .AccountsDidChange, object: nil)
	}
	
	var accounts: [Account] {
		get {
			return AccountManager.shared.accounts
		}
		set {
		}
	}
	
	var sortOldestToNewest: Bool {
		get {
			return AppDefaults.timelineSortDirection == .orderedDescending
		}
		set {
			if newValue == true {
				AppDefaults.timelineSortDirection = .orderedDescending
			} else {
				AppDefaults.timelineSortDirection = .orderedAscending
			}
			didChange.send(self)
		}
	}
	
	var timelineNumberOfLines: Int {
		get {
			return AppDefaults.timelineNumberOfLines
		}
		set {
			AppDefaults.timelineNumberOfLines = newValue
			didChange.send(self)
		}
	}
	
	var refreshInterval: RefreshInterval {
		get {
			return AppDefaults.refreshInterval
		}
		set {
			AppDefaults.refreshInterval = newValue
			didChange.send(self)
		}
	}
	
	@objc func accountsDidChange(_ notification: Notification) {
		didChange.send(self)
	}
	
}
