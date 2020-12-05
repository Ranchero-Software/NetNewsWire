//
//  AddNewsBlurAccountView.swift
//  Multiplatform macOS
//
//  Created by Stuart Breckenridge on 03/12/2020.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import RSCore
import RSWeb
import Secrets

struct AddNewsBlurAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddNewsBlurViewModel()
	
    var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					AccountType.newsBlur.image()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your NewsBlur account.")
						.font(.headline)
					HStack {
						Text("Don't have a NewsBlur account?")
							.font(.callout)
						Button(action: {
							NSWorkspace.shared.open(URL(string: "https://newsblur.com")!)
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
						ProgressView()
							.scaleEffect(CGSize(width: 0.5, height: 0.5))
							.hidden(!model.isAuthenticating)
						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Cancel")
								.frame(width: 60)
						}).keyboardShortcut(.cancelAction)

						Button(action: {
							presentationMode.wrappedValue.dismiss()
						}, label: {
							Text("Sign In")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(model.username.isEmpty || model.password.isEmpty)
					}
				}
			}
		}
		.padding()
		.frame(minWidth: 400, maxWidth: 400, minHeight: 230, maxHeight: 260)
		.textFieldStyle(RoundedBorderTextFieldStyle())
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
    }
	
	private func authenticateNewsBlur() {
		model.isAuthenticating = true
		let credentials = Credentials(type: .newsBlurBasic, username: model.username, secret: model.password)
		
		Account.validateCredentials(type: .newsBlur, credentials: credentials) { result in
			
			self.model.isAuthenticating = false
			
			switch result {
			case .success(let validatedCredentials):
				
				guard let validatedCredentials = validatedCredentials else {
					self.model.accountUpdateError = .invalidUsernamePassword
					self.model.showError = true
					return
				}
				
				let account = AccountManager.shared.createAccount(type: .newsBlur)
				
				do {
					try account.removeCredentials(type: .newsBlurBasic)
					try account.removeCredentials(type: .newsBlurSessionId)
					try account.storeCredentials(credentials)
					try account.storeCredentials(validatedCredentials)
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

struct AddNewsBlurAccountView_Previews: PreviewProvider {
    static var previews: some View {
        AddNewsBlurAccountView()
    }
}
