//
//  SettingsDetailAccountModel.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 08/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

class SettingsDetailAccountModel: ObservableObject {
	let account: Account
	@Published var name: String {
		didSet {
			account.name = name.isEmpty ? nil : name
		}
	}
	@Published var isActive: Bool {
		didSet {
			account.isActive = isActive
		}
	}

	init(_ account: Account) {
		self.account = account
		self.name = account.name ?? ""
		self.isActive = account.isActive
	}

	var defaultName: String {
		account.defaultName
	}

	var nameForDisplay: String {
		account.nameForDisplay
	}

	var accountImage: RSImage {
		AppAssets.image(for: account.type)!
	}

	var isCredentialsAvailable: Bool {
		return account.type != .onMyMac
	}

	var isDeletable: Bool {
		return AccountManager.shared.defaultAccount != account
	}

	func delete() {
		AccountManager.shared.deleteAccount(account)
	}
}
