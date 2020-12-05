//
//  AddReaderAPIAccountView.swift
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

struct AddReaderAPIAccountView: View {
	
	@Environment (\.presentationMode) var presentationMode
	@StateObject private var model = AddReaderAPIViewModel()
	public var accountType: AccountType
	
	var body: some View {
		VStack {
			HStack(spacing: 16) {
				VStack(alignment: .leading) {
					accountType.image()
						.resizable()
						.frame(width: 50, height: 50)
					Spacer()
				}
				VStack(alignment: .leading, spacing: 8) {
					Text("Sign in to your \(accountType.localizedAccountName()) account.")
						.font(.headline)
					HStack {
						if accountType == .freshRSS {
							Text("Don't have a \(accountType.localizedAccountName()) instance?")
								.font(.callout)
						} else {
							Text("Don't have an \(accountType.localizedAccountName()) account?")
								.font(.callout)
						}
						
						
						Button(action: {
							signUp()
						}, label: {
							Text(accountType == .freshRSS ? "Find out more." : "Sign up here.").font(.callout)
						}).buttonStyle(LinkButtonStyle())
					}
					
					HStack {
						VStack(alignment: .trailing, spacing: 14) {
							Text("Email")
							Text("Password")
							if accountType == .freshRSS {
								Text("API URL")
							}
						}
						VStack(spacing: 8) {
							TextField("me@email.com", text: $model.username)
							SecureField("•••••••••••", text: $model.password)
							if accountType == .freshRSS {
								TextField("https://myfreshrss.rocks", text: $model.apiUrl)
							}
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
							authenticateReaderAccount()
						}, label: {
							Text("Sign In")
								.frame(width: 60)
						})
						.keyboardShortcut(.defaultAction)
						.disabled(createDisabled())
					}
				}
			}
		}
		.padding()
		.frame(width: 400, height: height())
		.textFieldStyle(RoundedBorderTextFieldStyle())
		.alert(isPresented: $model.showError, content: {
			Alert(title: Text("Sign In Error"), message: Text(model.accountUpdateError.description), dismissButton: .cancel())
		})
	}
	
	func createDisabled() -> Bool {
		if accountType == .freshRSS {
			return model.username.isEmpty || model.password.isEmpty || !model.apiUrl.mayBeURL
		}
		return model.username.isEmpty || model.password.isEmpty
	}
	
	func height() -> CGFloat {
		if accountType == .freshRSS {
			return 260
		}
		return 230
	}
	
	private func signUp() {
		switch accountType {
		case .freshRSS:
			#if os(macOS)
			NSWorkspace.shared.open(URL(string: "https://freshrss.org")!)
			#endif
		case .inoreader:
			#if os(macOS)
			NSWorkspace.shared.open(URL(string: "https://www.inoreader.com")!)
			#endif
		case .bazQux:
			#if os(macOS)
			NSWorkspace.shared.open(URL(string: "https://bazqux.com")!)
			#endif
		case .theOldReader:
			#if os(macOS)
			NSWorkspace.shared.open(URL(string: "https://theoldreader.com")!)
			#endif
		default:
			return
		}
	}
	
	private func authenticateReaderAccount() {
		model.isAuthenticating = true
		
		let credentials = Credentials(type: .readerBasic, username: model.username, secret: model.password)
		
		if accountType == .freshRSS {
			Account.validateCredentials(type: accountType, credentials: credentials, endpoint: URL(string: model.apiUrl)!) { result in
				
				self.model.isAuthenticating = false
				
				switch result {
				case .success(let validatedCredentials):
					
					guard let validatedCredentials = validatedCredentials else {
						self.model.accountUpdateError = .invalidUsernamePassword
						self.model.showError = true
						return
					}
					
					let account = AccountManager.shared.createAccount(type: .freshRSS)
					
					do {
						try account.removeCredentials(type: .readerBasic)
						try account.removeCredentials(type: .readerAPIKey)
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
		
		else {
			
			Account.validateCredentials(type: accountType, credentials: credentials) { result in
				
				self.model.isAuthenticating = false
				
				switch result {
				case .success(let validatedCredentials):
					
					guard let validatedCredentials = validatedCredentials else {
						self.model.accountUpdateError = .invalidUsernamePassword
						self.model.showError = true
						return
					}
					
					let account = AccountManager.shared.createAccount(type: .freshRSS)
					
					do {
						try account.removeCredentials(type: .readerBasic)
						try account.removeCredentials(type: .readerAPIKey)
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
	
	
}

struct AddReaderAPIAccountView_Previews: PreviewProvider {
	static var previews: some View {
		AddReaderAPIAccountView(accountType: .freshRSS)
	}
}
