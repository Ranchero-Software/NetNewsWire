//
//  SettingsAddAccountModel.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 09/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore

class SettingsAddAccountModel: ObservableObject {

	struct SettingsAddAccount: Identifiable {
		var id: Int { accountType.rawValue }

		let name: String
		let accountType: AccountType

		var image: RSImage {
			AppAssets.image(for: accountType)!
		}
	}

	@Published var accounts: [SettingsAddAccount] = []
	@Published var isAddPresented = false
	@Published var selectedAccountType: AccountType? = nil {
		didSet {
			selectedAccountType != nil ? (isAddPresented = true) : (isAddPresented = false)
		}
	}

	init() {
		self.accounts = [
			SettingsAddAccount(name: Account.defaultLocalAccountName, accountType: .onMyMac),
			SettingsAddAccount(name: "Feedbin", accountType: .feedbin),
			SettingsAddAccount(name: "Feedly", accountType: .feedly),
			SettingsAddAccount(name: "Feed Wrangler", accountType: .feedWrangler),
			SettingsAddAccount(name: "iCloud", accountType: .cloudKit),
			SettingsAddAccount(name: "NewsBlur", accountType: .newsBlur),
			SettingsAddAccount(name: "Fresh RSS", accountType: .freshRSS)
		]
	}

}
