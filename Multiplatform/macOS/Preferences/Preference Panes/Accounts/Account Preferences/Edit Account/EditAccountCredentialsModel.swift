//
//  EditAccountCredentialsModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 14/7/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account
import Secrets
import RSCore

class EditAccountCredentialsModel: ObservableObject {
	
	@Published var userName: String = ""
	@Published var password: String = ""
	@Published var apiUrl: String = ""
	@Published var accountIsUpdatingCredentials: Bool = false
	@Published var accountCredentialsWereUpdated: Bool = false
	@Published var error: AccountUpdateErrors = .none {
		didSet {
			if error == .none {
				showError = false
			} else {
				showError = true
			}
		}
	}
	@Published var showError: Bool = false
	
	func updateAccountCredentials(_ account: Account) {
		switch account.type {
		case .onMyMac:
			return
		case .feedbin:
			updateFeedbin(account)
		case .cloudKit:
			return
		case .feedWrangler:
			updateFeedWrangler(account)
		case .feedly:
			updateFeedly(account)
		case .freshRSS:
			updateReaderAccount(account)
		case .newsBlur:
			updateNewsblur(account)
		case .inoreader:
			updateReaderAccount(account)
		case .bazQux:
			updateReaderAccount(account)
		case .theOldReader:
			updateReaderAccount(account)
		}
	}
	
	func retrieveCredentials(_ account: Account) {
		switch account.type {
		case .feedbin:
			let credentials = try? account.retrieveCredentials(type: .basic)
			userName = credentials?.username ?? ""
		case .feedWrangler:
			let credentials = try? account.retrieveCredentials(type: .feedWranglerBasic)
			userName = credentials?.username ?? ""
		case .feedly:
			return
		case .freshRSS:
			let credentials = try? account.retrieveCredentials(type: .readerBasic)
			userName = credentials?.username ?? ""
		case .newsBlur:
			let credentials = try? account.retrieveCredentials(type: .newsBlurBasic)
			userName = credentials?.username ?? ""
		default:
			return
		}
	}
	
}

// MARK:- Update API
extension EditAccountCredentialsModel {
	
	func updateFeedbin(_ account: Account) {
		accountIsUpdatingCredentials = true
		let credentials = Credentials(type: .basic, username: userName, secret: password)
		
		Account.validateCredentials(type: .feedbin, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsUpdatingCredentials = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.error = .invalidUsernamePassword
					return
				}
				
				do {
					try account.removeCredentials(type: .basic)
					try account.storeCredentials(validatedCredentials)
					self.accountCredentialsWereUpdated = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.error = .other(error: error)
						}
					})
					
				} catch {
					self.error = .keyChainError
				}
				
			case .failure:
				self.error = .networkError
			}
		}
	}
	
	func updateFeedWrangler(_ account: Account) {
		accountIsUpdatingCredentials = true
		let credentials = Credentials(type: .feedWranglerBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: .feedWrangler, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsUpdatingCredentials = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.error = .invalidUsernamePassword
					return
				}
				
				do {
					try account.removeCredentials(type: .feedWranglerBasic)
					try account.removeCredentials(type: .feedWranglerToken)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountCredentialsWereUpdated = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.error = .other(error: error)
						}
					})
					
				} catch {
					self.error = .keyChainError
				}
				
			case .failure:
				self.error = .networkError
			}
		}
	}
	
	func updateFeedly(_ account: Account) {
		accountIsUpdatingCredentials = true
		let updateAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
		updateAccount.delegate = self
		#if os(macOS)
		updateAccount.presentationAnchor = NSApplication.shared.windows.last
		#endif
		MainThreadOperationQueue.shared.add(updateAccount)
	}
	
	func updateReaderAccount(_ account: Account) {
		accountIsUpdatingCredentials = true
		let credentials = Credentials(type: .readerBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: account.type, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsUpdatingCredentials = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.error = .invalidUsernamePassword
					return
				}
				
				do {
					try account.removeCredentials(type: .readerBasic)
					try account.removeCredentials(type: .readerAPIKey)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountCredentialsWereUpdated = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.error = .other(error: error)
						}
					})
					
				} catch {
					self.error = .keyChainError
				}
				
			case .failure:
				self.error = .networkError
			}
		}
	}
	
	func updateNewsblur(_ account: Account) {
		accountIsUpdatingCredentials = true
		let credentials = Credentials(type: .newsBlurBasic, username: userName, secret: password)
		
		Account.validateCredentials(type: .newsBlur, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.accountIsUpdatingCredentials = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.error = .invalidUsernamePassword
					return
				}
				
				do {
					try account.removeCredentials(type: .newsBlurBasic)
					try account.removeCredentials(type: .newsBlurSessionId)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.accountCredentialsWereUpdated = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.error = .other(error: error)
						}
					})
					
				} catch {
					self.error = .keyChainError
				}
				
			case .failure:
				self.error = .networkError
			}
		}
	}
	
}

// MARK:- OAuthAccountAuthorizationOperationDelegate
extension EditAccountCredentialsModel: OAuthAccountAuthorizationOperationDelegate {
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		accountIsUpdatingCredentials = false
		accountCredentialsWereUpdated = true
		account.refreshAll { [weak self] result in
			switch result {
			case .success:
				break
			case .failure(let error):
				self?.error = .other(error: error)
			}
		}
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		accountIsUpdatingCredentials = false
		self.error = .other(error: error)
	}
}
