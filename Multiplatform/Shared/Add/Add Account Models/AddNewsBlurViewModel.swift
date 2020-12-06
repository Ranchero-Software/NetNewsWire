//
//  AddNewsBlurViewModel.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 05/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

class AddNewsBlurViewModel: ObservableObject, AddAccountSignUp {
	@Published var isAuthenticating: Bool = false
	@Published var accountUpdateError: AccountUpdateErrors = .none
	@Published var showError: Bool = false
	@Published var username: String = ""
	@Published var password: String = ""
	@Published var canDismiss: Bool = false
	@Published var showPassword: Bool = false
	
	func authenticateNewsBlur() {
		isAuthenticating = true
		let credentials = Credentials(type: .newsBlurBasic, username: username, secret: password)
		
		Account.validateCredentials(type: .newsBlur, credentials: credentials) { result in
			
			self.isAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.accountUpdateError = .invalidUsernamePassword
					self.showError = true
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .newsBlur)
				
				do {
					try account.removeCredentials(type: .newsBlurBasic)
					try account.removeCredentials(type: .newsBlurSessionId)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
					self.canDismiss = true
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							self.accountUpdateError = .other(error: error)
							self.showError = true
						}
					})
					
				} catch {
					self.accountUpdateError = .keyChainError
					self.showError = true
				}
				
			case .failure:
				self.accountUpdateError = .networkError
				self.showError = true
			}
		}
	}
	
}
