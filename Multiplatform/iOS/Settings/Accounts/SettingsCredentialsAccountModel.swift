//
//  SettingsCredentialsAccountModel.swift
//  Multiplatform iOS
//
//  Created by Rizwan on 21/07/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Secrets

class SettingsCredentialsAccountModel: ObservableObject {
	var account: Account? = nil
	var accountType: AccountType
	@Published var shouldDismiss: Bool = false
	@Published var email: String = ""
	@Published var password: String = ""
	@Published var apiUrl: String = ""
	@Published var busy: Bool = false
	@Published var accountCredentialsError: AccountCredentialsError? {
		didSet {
			accountCredentialsError != AccountCredentialsError.none ? (showError = true) : (showError = false)
		}
	}
	@Published var showError: Bool = false
	@Published var showPassword: Bool = false

	init(account: Account) {
		self.account = account
		self.accountType = account.type
		if let credentials = try? account.retrieveCredentials(type: .basic) {
			self.email = credentials.username
			self.password = credentials.secret
		}
	}

	init(accountType: AccountType) {
		self.accountType = accountType
	}

	var isUpdate: Bool {
		return account != nil
	}

	var isValid: Bool {
		if apiUrlEnabled {
			return !email.isEmpty && !password.isEmpty && !apiUrl.isEmpty
		}
		return !email.isEmpty && !password.isEmpty
	}

	var accountName: String {
		switch accountType {
		case .onMyMac:
			return Account.defaultLocalAccountName
		case .cloudKit:
			return "iCloud"
		case .feedbin:
			return "Feedbin"
		case .feedly:
			return "Feedly"
		case .feedWrangler:
			return "Feed Wrangler"
		case .newsBlur:
			return "NewsBlur"
		default:
			return ""
		}
	}

	var emailText: String {
		return accountType == .newsBlur ? NSLocalizedString("Username or Email", comment: "") : NSLocalizedString("Email", comment: "")
	}

	var apiUrlEnabled: Bool {
		return accountType == .freshRSS
	}

	func addAccount() {
		switch accountType {
		case .feedbin:
			addFeedbinAccount()
		case .feedWrangler:
			addFeedWranglerAccount()
		case .newsBlur:
			addNewsBlurAccount()
		case .freshRSS:
			addFreshRSSAccount()
		default:
			return
		}
	}
}

extension SettingsCredentialsAccountModel {
	// MARK:- Feedbin

	func addFeedbinAccount() {
		busy = true
		accountCredentialsError = AccountCredentialsError.none

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
						self.accountCredentialsError = AccountCredentialsError.keyChain
					}

				} else {
					self.accountCredentialsError = AccountCredentialsError.invalidCredentials
				}
			case .failure:
				self.accountCredentialsError = AccountCredentialsError.noNetwork
			}
		}
	}

	// MARK: FeedWrangler

	func addFeedWranglerAccount() {
		busy = true
		let credentials = Credentials(type: .feedWranglerBasic, username: email, secret: password)

		Account.validateCredentials(type: .feedWrangler, credentials: credentials) { [weak self] result in
			guard let self = self else { return }

			self.busy = false
			switch result {
			case .success(let validatedCredentials):
				guard let validatedCredentials = validatedCredentials else {
					self.accountCredentialsError = .invalidCredentials
					return
				}

				let account = AccountManager.shared.createAccount(type: .feedWrangler)
				do {
					try account.removeCredentials(type: .feedWranglerBasic)
					try account.removeCredentials(type: .feedWranglerToken)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.shouldDismiss = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.accountCredentialsError = .other(error: error)
						}
					})

				} catch {
					self.accountCredentialsError = .keyChain
				}

			case .failure:
				self.accountCredentialsError = .noNetwork
			}
		}
	}

	// MARK:- NewsBlur

	func addNewsBlurAccount() {
		busy = true
		let credentials = Credentials(type: .newsBlurBasic, username: email, secret: password)

		Account.validateCredentials(type: .newsBlur, credentials: credentials) { [weak self] result in

			guard let self = self else { return }

			self.busy = false

			switch result {
			case .success(let validatedCredentials):

				guard let validatedCredentials = validatedCredentials else {
					self.accountCredentialsError = .invalidCredentials
					return
				}

				let account = AccountManager.shared.createAccount(type: .newsBlur)

				do {
					try account.removeCredentials(type: .newsBlurBasic)
					try account.removeCredentials(type: .newsBlurSessionId)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.shouldDismiss = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.accountCredentialsError = .other(error: error)
						}
					})

				} catch {
					self.accountCredentialsError = .keyChain
				}

			case .failure:
				self.accountCredentialsError = .noNetwork
			}
		}
	}

	// MARK:- Fresh RSS

	func addFreshRSSAccount() {
		busy = true
		let credentials = Credentials(type: .readerBasic, username: email, secret: password)

		Account.validateCredentials(type: .freshRSS, credentials: credentials, endpoint: URL(string: apiUrl)!) { [weak self] result in

			guard let self = self else { return }

			self.busy = false

			switch result {
			case .success(let validatedCredentials):

				guard let validatedCredentials = validatedCredentials else {
					self.accountCredentialsError = .invalidCredentials
					return
				}

				let account = AccountManager.shared.createAccount(type: .freshRSS)

				do {
					try account.removeCredentials(type: .readerBasic)
					try account.removeCredentials(type: .readerAPIKey)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.shouldDismiss = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.accountCredentialsError = .other(error: error)
						}
					})

				} catch {
					self.accountCredentialsError = .keyChain
				}

			case .failure:
				self.accountCredentialsError = .noNetwork
			}
		}
	}
}
