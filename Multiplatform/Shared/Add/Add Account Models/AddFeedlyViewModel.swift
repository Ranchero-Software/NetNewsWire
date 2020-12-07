//
//  AddFeedlyViewModel.swift
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

class AddFeedlyViewModel: ObservableObject, OAuthAccountAuthorizationOperationDelegate, AddAccountSignUp  {
	@Published var isAuthenticating: Bool = false
	@Published var accountUpdateError: AccountUpdateErrors = .none
	@Published var showError: Bool = false
	@Published var username: String = ""
	@Published var password: String = ""
	
	func authenticateFeedly() {
		isAuthenticating = true
		let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
		addAccount.delegate = self
		#if os(macOS)
		addAccount.presentationAnchor = NSApplication.shared.windows.last
		#else
		addAccount.presentationAnchor = UIApplication.shared.windows.last
		#endif
		MainThreadOperationQueue.shared.add(addAccount)
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didCreate account: Account) {
		
		isAuthenticating = false
		
		// macOS only: `ASWebAuthenticationSession` leaves the browser in the foreground.
		// Ensure the app is in the foreground so the user can see their Feedly account load.
		#if os(macOS)
		NSApplication.shared.activate(ignoringOtherApps: true)
		#endif
		
		account.refreshAll { [weak self] result in
			switch result {
			case .success:
				break
			case .failure(let error):
				self?.accountUpdateError = .other(error: error)
				self?.showError = true
			}
		}
	}
	
	func oauthAccountAuthorizationOperation(_ operation: OAuthAccountAuthorizationOperation, didFailWith error: Error) {
		isAuthenticating = false
		
		// macOS only: `ASWebAuthenticationSession` leaves the browser in the foreground.
		// Ensure the app is in the foreground so the user can see the error.
		#if os(macOS)
		NSApplication.shared.activate(ignoringOtherApps: true)
		#endif
		
		accountUpdateError = .other(error: error)
		showError = true
	}
}
