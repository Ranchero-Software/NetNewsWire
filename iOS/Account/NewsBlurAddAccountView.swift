//
//  NewsBlurAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 18/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Secrets
import RSWeb
import RSCore

struct NewsBlurAddAccountView: View, Logging {
    
	@Environment(\.dismiss) private var dismiss
	@State var account: Account? = nil
	@State private var accountUserName: String = ""
	@State private var accountPassword: String = ""
	@State private var showProgressIndicator: Bool = false
	@State private var accountError: (Error?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			Form {
				AccountSectionHeader(accountType: .newsBlur)
				accountDetails
				accountButton
				Section(footer: newsBlurAccountExplainer) {}
			}
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { dismiss() }, label: { Text("Cancel", comment: "Button title") })
						.disabled(showProgressIndicator)
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					if showProgressIndicator { ProgressView() }
				}
			}
			.navigationTitle(Text(AccountType.newsBlur.localizedAccountName()))
			.navigationBarTitleDisplayMode(.inline)
			.task {
				retreiveCredentials()
			}
			.alert(Text("Error", comment: "Alert title: Error"), isPresented: $accountError.1) {
				Button(role: .cancel) {
					//
				} label: {
					Text("Dismiss", comment: "Button title")
				}
			} message: {
				Text(accountError.0?.localizedDescription ?? "")
			}
			.interactiveDismissDisabled(showProgressIndicator)
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
    }
	
	func retreiveCredentials() {
		if let account = account {
			do {
				let credentials = try account.retrieveCredentials(type: .newsBlurBasic)
				if let credentials = credentials {
					self.accountUserName = credentials.username
					self.accountPassword = credentials.secret
				} else {
					print("No cred")
				}
			} catch {
				print(error.localizedDescription)
			}
		} else {
			print("No account")
		}
		
	}
	
	var accountDetails: some View {
		Section {
			TextField("Email", text: $accountUserName, prompt: Text("Username or Email", comment: "Textfield for the user to enter their account username or email."))
				.autocorrectionDisabled()
				.autocapitalization(.none)
				.textContentType(.username)
			SecureField("Password", text: $accountPassword, prompt: Text("Password", comment: "Textfield for the user to enter their account password."))
				.textContentType(.password)
		}
	}
	
	var accountButton: some View {
		Section {
			Button {
				Task {
					do {
						if account == nil {
							// Create a new account
							try await executeAccountCredentials()
						} else {
							// Updating account credentials
							try await executeAccountCredentials()
							dismiss()
						}
					} catch {
						accountError = (error, true)
					}
				}
			} label: {
				HStack{
					Spacer()
					if account == nil {
						Text("Add Account", comment: "Button title")
					} else {
						Text("Update Credentials", comment: "Button title")
					}
					Spacer()
				}
			}
		}
	}
	
	var newsBlurAccountExplainer: some View {
		if account == nil {
			return Text("Sign in to your NewsBlur account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a NewsBlur account? [Sign Up Here](https://newsblur.com)", comment: "Explanatory text describing the NewsBlur account")
				.multilineTextAlignment(.center)
		}
		return Text("").multilineTextAlignment(.center)
	}
	
	private func executeAccountCredentials() async throws {
		let trimmedUsername = accountUserName.trimmingWhitespace
		
		guard (account != nil || !AccountManager.shared.duplicateServiceAccount(type: .newsBlur, username: trimmedUsername)) else {
			throw LocalizedNetNewsWireError.duplicateAccount
		}
		showProgressIndicator = true
		
		let basicCredentials = Credentials(type: .newsBlurBasic, username: trimmedUsername, secret: accountPassword)
		
		return try await withCheckedThrowingContinuation { continuation in
			Account.validateCredentials(type: .newsBlur, credentials: basicCredentials) { result in
				switch result {
				case .success(let credentials):
					if let sessionsCredentials = credentials {
						
						if self.account == nil {
							self.account = AccountManager.shared.createAccount(type: .newsBlur)
						}
						
						do {
							do {
								try self.account?.removeCredentials(type: .newsBlurBasic)
								try self.account?.removeCredentials(type: .newsBlurSessionId)
							} catch {
								NewsBlurAddAccountView.logger.error("\(error.localizedDescription)")
							}
						
							try self.account?.storeCredentials(basicCredentials)
							try self.account?.storeCredentials(sessionsCredentials)
							
							self.account?.refreshAll(completion: { result in
								switch result {
								case .success(_):
									showProgressIndicator = false
									continuation.resume()
									return
								case .failure(let failure):
									showProgressIndicator = false
									continuation.resume(throwing: failure)
									return
								}
							})
						} catch {
							showProgressIndicator = false
							continuation.resume(throwing: LocalizedNetNewsWireError.keychainError)
							return
						}
					} else {
						showProgressIndicator = false
						continuation.resume(throwing: LocalizedNetNewsWireError.invalidUsernameOrPassword)
						return
					}
				case .failure(let failure):
					showProgressIndicator = false
					continuation.resume(throwing: failure)
					return
				}
			}
		}
	}
}

struct NewsBlurAddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        NewsBlurAddAccountView()
    }
}
