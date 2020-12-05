//
//  AddFeedlyAccountView.swift
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

fileprivate class AddFeedlyViewModel: ObservableObject, OAuthAccountAuthorizationOperationDelegate  {
	@Published var isAuthenticating: Bool = false
	@Published var accountUpdateError: AccountUpdateErrors = .none
	@Published var showError: Bool = false
	@Published var username: String = ""
	@Published var password: String = ""
	
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

struct AddFeedlyAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddFeedlyViewModel()
	
    var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.feedly.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your Feedly account.")
						.font(.headline)
					HStack {
						Text("Don't have a Feedly account?")
							.font(.callout)
						Button(action: {
							NSWorkspace.shared.open(URL(string: "https://feedly.com")!)
						}, label: {
							Text("Sign up here.").font(.callout)
						}).buttonStyle(LinkButtonStyle())
					}
					
					Spacer()
					HStack(spacing: 8) {
						Spacer()
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)

						Button(action: {
							authenticateFeedly()
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Sign In")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(AccountManager.shared.activeAccounts.filter({ $0.type == .cloudKit }).count > 0)
					}
				}
			}
		}
		.padding()
		.frame(minWidth: 400, maxWidth: 400, maxHeight: 150)
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
    }
	
	private func authenticateFeedly() {
		model.isAuthenticating = true
		let addAccount = OAuthAccountAuthorizationOperation(accountType: .feedly)
		addAccount.delegate = model
		#if os(macOS)
		addAccount.presentationAnchor = NSApplication.shared.windows.last
		#endif
		MainThreadOperationQueue.shared.add(addAccount)
	}
}

struct AddFeedlyAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedlyAccountView()
    }
}
