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

public enum AccountConfigurationSheets: Equatable {
	case addAccountPicker, addSelectedAccount(AccountType), credentials, none
	
	public static func == (lhs: AccountConfigurationSheets, rhs: AccountConfigurationSheets) -> Bool {
		switch (lhs, rhs) {
		case (let .addSelectedAccount(lhsType), let .addSelectedAccount(rhsType)):
			return lhsType == rhsType
		default:
			return false
		}
	}
	
}

public class AccountsPreferencesModel: ObservableObject {
	
	// Selected Account
	public private(set) var account: Account?
	
	// All Accounts
	@Published var sortedAccounts: [Account] = []
	@Published var selectedConfiguredAccountID: String? = AccountManager.shared.defaultAccount.accountID {
		didSet {
			if let accountID = selectedConfiguredAccountID {
				account = sortedAccounts.first(where: { $0.accountID == accountID })
				accountIsActive = account?.isActive ?? false
				accountName = account?.name ?? ""
			}
		}
	}
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
	
	// Edit Account
	@Published var accountIsActive: Bool = false {
		didSet {
			account?.isActive = accountIsActive
		}
	}
	@Published var accountName: String = "" {
		didSet {
			account?.name = accountName
		}
	}
	
	// Sheets
	@Published var showSheet: Bool = false
	@Published var sheetToShow: AccountConfigurationSheets = .none {
		didSet {
			if sheetToShow == .none { showSheet = false } else { showSheet = true }
		}
	}
	@Published var showDeleteConfirmation: Bool = false
	
	// Subscriptions
	var cancellables = Set<AnyCancellable>()
	
	init() {
		sortedAccounts = AccountManager.shared.sortedAccounts
		
		NotificationCenter.default.publisher(for: .UserDidAddAccount).sink {  [weak self] _ in
			self?.sortedAccounts = AccountManager.shared.sortedAccounts
		}.store(in: &cancellables)
		
		NotificationCenter.default.publisher(for: .UserDidDeleteAccount).sink { [weak self] _ in
			self?.selectedConfiguredAccountID = nil
			self?.sortedAccounts = AccountManager.shared.sortedAccounts
			self?.selectedConfiguredAccountID = AccountManager.shared.defaultAccount.accountID
		}.store(in: &cancellables)
		
		NotificationCenter.default.publisher(for: .AccountStateDidChange).sink { [weak self] notification in
			guard let account = notification.object as? Account else {
				return
			}
			if account.accountID == self?.account?.accountID {
				self?.account = account
				self?.accountIsActive = account.isActive
				self?.accountName = account.name ?? ""
			}
		}.store(in: &cancellables)
	}
	
}
