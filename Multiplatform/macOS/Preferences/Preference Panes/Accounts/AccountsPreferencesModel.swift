//
//  AccountsPreferencesModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 13/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Combine

class AccountsPreferencesModel: ObservableObject {
	
	@Published var sortedAccounts: [Account] = []
	@Published var selectedConfiguredAccountID: String? = nil
	@Published var showAddAccountView: Bool = false
	
	var selectedAccountIsDefault: Bool {
		guard let selected = selectedConfiguredAccountID else {
			return true
		}
		if selected == AccountManager.shared.defaultAccount.accountID {
			return true
		}
		return false
	}
	
	// Subscriptions
	var notificationSubscriptions = Set<AnyCancellable>()
	
	init() {
		sortedAccounts = AccountManager.shared.sortedAccounts
		
		NotificationCenter.default.publisher(for: .UserDidAddAccount).sink(receiveValue: {  _ in
			self.sortedAccounts = AccountManager.shared.sortedAccounts
		}).store(in: &notificationSubscriptions)
		
		NotificationCenter.default.publisher(for: .UserDidDeleteAccount).sink(receiveValue: { _ in
			self.selectedConfiguredAccountID = nil
			self.sortedAccounts = AccountManager.shared.sortedAccounts
		}).store(in: &notificationSubscriptions)
	}
	
}
