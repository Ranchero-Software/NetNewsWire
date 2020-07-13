//
//  SettingsFeedbinAccountModel.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 08/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Secrets

enum FeedbinAccountError: LocalizedError {

	case none, keyChain, invalidCredentials, noNetwork

	var errorDescription: String? {
		switch self {
		case .keyChain:
			return NSLocalizedString("Keychain error while storing credentials.", comment: "")
		case .invalidCredentials:
			return NSLocalizedString("Invalid email/password combination.", comment: "")
		case .noNetwork:
			return NSLocalizedString("Network error. Try again later.", comment: "")
		default:
			return nil
		}
	}

}

class SettingsFeedbinAccountModel: ObservableObject {
	var account: Account? = nil
	@Published var shouldDismiss: Bool = false
	@Published var email: String = ""
	@Published var password: String = ""
	@Published var busy: Bool = false
	@Published var feedbinAccountError: FeedbinAccountError? {
		didSet {
			feedbinAccountError != FeedbinAccountError.none ? (showError = true) : (showError = false)
		}
	}
	@Published var showError: Bool = false
	@Published var showPassword: Bool = false

	init() {

	}

	init(account: Account) {
		self.account = account
		if let credentials = try? account.retrieveCredentials(type: .basic) {
			self.email = credentials.username
			self.password = credentials.secret
		}
	}

	var isUpdate: Bool {
		return account != nil
	}

	var isValid: Bool {
		return !email.isEmpty && !password.isEmpty
	}

	func addAccount() {
		busy = true
		feedbinAccountError = FeedbinAccountError.none

		let emailAddress = email.trimmingCharacters(in: .whitespaces)
		let credentials = Credentials(type: .basic, username: emailAddress, secret: password)

		Account.validateCredentials(type: .feedbin, credentials: credentials) { (result) in
			self.busy = false

			switch result {
			case .success(let authenticated):
				if (authenticated != nil) {
					var newAccount = false
					let workAccount: Account
					if self.account == nil {
						workAccount = AccountManager.shared.createAccount(type: .feedbin)
						newAccount = true
					} else {
						workAccount = self.account!
					}

					do {
						do {
							try workAccount.removeCredentials(type: .basic)
						} catch {}
						try workAccount.storeCredentials(credentials)

						if newAccount {
							workAccount.refreshAll() { result in }
						}

						self.shouldDismiss = true
					} catch {
						self.feedbinAccountError = FeedbinAccountError.keyChain
					}

				} else {
					self.feedbinAccountError = FeedbinAccountError.invalidCredentials
				}
			case .failure:
				self.feedbinAccountError = FeedbinAccountError.noNetwork
			}
		}
	}
}

