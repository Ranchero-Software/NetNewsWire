//
//  AddAccountModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 13/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import RSWeb
import Secrets
import RSCore

class AddAccountModel: ObservableObject {
	
	#if DEBUG
	let addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly, .feedWrangler, .freshRSS, .cloudKit, .newsBlur]
	#else
	let addableAccountTypes: [AccountType] = [.onMyMac, .feedbin, .feedly]
	#endif
	
	// Add Accounts
	@Published var selectedAddAccount: AccountType = .onMyMac
	@Published var userName: String = ""
	@Published var password: String = ""
	@Published var apiUrl: String = ""
	@Published var newLocalAccountName: String = ""
	@Published var accountIsAuthenticating: Bool = false
	@Published var addAccountError: AccountUpdateErrors = .none {
		didSet {
			if addAccountError == .none {
				showError = false
			} else {
				showError = true
			}
		}
	}
	@Published var showError: Bool = false
	@Published var accountAdded: Bool = false
		
	func resetUserEntries() {
		userName = ""
		password = ""
		newLocalAccountName = ""
		apiUrl = ""
	}
	
	func authenticateAccount() {
		switch selectedAddAccount {
		case .onMyMac:
			addLocalAccount()
		case .cloudKit:
			authenticateCloudKit()
		case .feedbin:
			authenticateFeedbin()
		case .feedWrangler:
			authenticateFeedWrangler()
		case .freshRSS:
			authenticateFreshRSS()
		case .feedly:
			authenticateFeedly()
		case .newsBlur:
			authenticateNewsBlur()
		}
	}
	
}

// MARK:- Authentication APIs

extension AddAccountModel {
	
	private func addLocalAccount() {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		account.name = newLocalAccountName
		accountAdded = true
	}
	
	private func authenticateFeedbin() {
		accountIsAuthenticating = true
		let credentials = Credentials(type: .basic, username: userName, secret: password)
		
		Account.validateCredentials(type: .feedbin, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.addAccountError = .invalidUsernamePassword
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .feedbin)
				
				do {
					try account.removeCredentials(type: .basic)
					try account.storeCredentials(validatedCredentials)
					self.accountAdded = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.addAccountError = .other(error: error)
						}
					})
					
				} catch {
					self.addAccountError = .keyChainError
				}
				
			case .failure:
				self.addAccountError = .networkError
			}
			
		}
		
	}
	
	private func authenticateFeedWrangler() {
		
		accountIsAuthenticating = true
		let credentials = Credentials(type: .feedWranglerBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: .feedWrangler, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.addAccountError = .invalidUsernamePassword
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .feedWrangler)
				
				do {
					try account.removeCredentials(type: .feedWranglerBasic)
					try account.removeCredentials(type: .feedWranglerToken)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountAdded = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.addAccountError = .other(error: error)
						}
					})
					
				} catch {
					self.addAccountError = .keyChainError
				}
				
			case .failure:
				self.addAccountError = .networkError
			}
		}
	}
	
	private func authenticateNewsBlur() {
		accountIsAuthenticating = true
		let credentials = Credentials(type: .newsBlurBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: .newsBlur, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.addAccountError = .invalidUsernamePassword
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .newsBlur)
				
				do {
					try account.removeCredentials(type: .newsBlurBasic)
					try account.removeCredentials(type: .newsBlurSessionId)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountAdded = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.addAccountError = .other(error: error)
						}
					})
					
				} catch {
					self.addAccountError = .keyChainError
				}
				
			case .failure:
				self.addAccountError = .networkError
			}
		}
		
	}
	
	private func authenticateFreshRSS() {
		accountIsAuthenticating = true
		let credentials = Credentials(type: .readerBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: .freshRSS, credentials: credentials, endpoint: URL(string: apiUrl)!) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.addAccountError = .invalidUsernamePassword
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .freshRSS)
				
				do {
					try account.removeCredentials(type: .readerBasic)
					try account.removeCredentials(type: .readerAPIKey)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountAdded = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.addAccountError = .other(error: error)
						}
					})
					
				} catch {
					self.addAccountError = .keyChainError
				}
				
			case .failure:
				self.addAccountError = .networkError
			}
		}
	}
	
	private func authenticateCloudKit() {
		let _ = AccountManager.shared.createAccount(type: .cloudKit)
		self.accountAdded = true
	}
	
	private func authenticateFeedly() {
		accountIsAuthenticating = true
		let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
		addAccount.delegate = self
		addAccount.presentationAnchor = NSApplication.shared.windows.last
		MainThreadOperationQueue.shared.add(addAccount)
	}
	
}

// MARK:- OAuthAccountAuthorizationOperationDelegate
extension AddAccountModel: OAuthAccountAuthorizationOperationDelegate {
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		accountIsAuthenticating = false
		accountAdded = true
		account.refreshAll { [weak self] result in
			switch result {
			case .success:
				break
			case .failure(let error):
				self?.addAccountError = .other(error: error)
			}
		}
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		accountIsAuthenticating = false
		addAccountError = .other(error: error)
	}
}
