//
//  AddFeedbinAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 02/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

fileprivate class AddFeedbinViewModel: ObservableObject {
	
	@Published var isAuthenticating: Bool = false
	@Published var accountUpdateError: AccountUpdateErrors = .none
	@Published var showError: Bool = false
	@Published var username: String = ""
	@Published var password: String = ""
	
}


struct AddFeedbinAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddFeedbinViewModel()
 
	var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.feedbin.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your Feedbin account.")
						.font(.headline)
					HStack {
						Text("Don't have a Feedbin account?")
							.font(.callout)
						Button(action: {
							NSWorkspace.shared.open(URL(string: "https://feedbin.com/signup")!)
						}, label: {
							Text("Sign up here.").font(.callout)
						}).buttonStyle(LinkButtonStyle())
					}
					
					HStack {
						VStack(alignment: .trailing, spacing: 14) {
							Text("Email")
							Text("Password")
						}
						VStack(spacing: 8) {
							TextField("me@email.com", text: $model.username)
							SecureField("•••••••••••", text: $model.password)
						}
					}
					
					Text("Your username and password will be encrypted and stored in Keychain.")
						.foregroundColor(.secondary)
						.font(.callout)
						.lineLimit(2)
						.padding(.top, 4)
					
					Spacer()
					HStack(spacing: 8) {
						Spacer()
						if model.isAuthenticating {
							ProgressView()
						}
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)

						Button(action: {
							authenticateFeedbin()
						}, label: {
							Text("Create")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(model.username.isEmpty || model.password.isEmpty)
					}
				}
			}
		}
		.padding()
		.frame(width: 384, height: 230)
		.textFieldStyle(RoundedBorderTextFieldStyle())
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
    }
	
	private func authenticateFeedbin() {
		model.isAuthenticating = true
		let credentials = Credentials(type: .basic, username: model.username, secret: model.password)
		
		Account.validateCredentials(type: .feedbin, credentials: credentials) { result in
			self.model.isAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.model.accountUpdateError = .invalidUsernamePassword
					self.model.showError = true
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .feedbin)
				
				do {
					try account.removeCredentials(type: .basic)
					try account.storeCredentials(validatedCredentials)
					self.model.isAuthenticating = false
					account.refreshAll(completion: { result in
						switch result {
						case .success:
							self.presentationMode.wrappedValue.dismiss()
						case .failure(let error):
							self.model.accountUpdateError = .other(error: error)
							self.model.showError = true
						}
					})
					
				} catch {
					self.model.accountUpdateError = .keyChainError
					self.model.showError = true
				}
				
			case .failure:
				self.model.accountUpdateError = .networkError
				self.model.showError = true
			}
		}
	}
}

struct AddFeedbinAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddFeedbinAccountView()
    }
}
