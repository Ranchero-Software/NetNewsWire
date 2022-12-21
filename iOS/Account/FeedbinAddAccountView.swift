//
//  FeedbinAddAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 18/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Secrets
import RSWeb
import SafariServices
import RSCore


struct FeedbinAddAccountView: View {
	
	@Environment(\.dismiss) private var dismiss
	@State var account: Account? = nil
	@State private var accountEmail: String = ""
	@State private var accountPassword: String = ""
	@State private var showProgressIndicator: Bool = false
	@State private var accountError: (Error?, Bool) = (nil, false)
	
    var body: some View {
		NavigationView {
			Form {
				AccountSectionHeader(accountType: .feedbin)
				accountDetails
				accountButton
				Section(footer: feedbinAccountExplainer) {}
			}
			.task {
				retrieveCredentials()
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
			.alert(Text("Error", comment: "Alert title: Error"), isPresented: $accountError.1) {
				Button(role: .cancel) {
					//
				} label: {
					Text("Dismiss", comment: "Button title")
				}
			} message: {
				Text(accountError.0?.localizedDescription ?? "Error")
			}
			.navigationTitle(Text(verbatim: account?.type.localizedAccountName() ?? "Feedbin"))
			.navigationBarTitleDisplayMode(.inline)
			.interactiveDismissDisabled(showProgressIndicator)
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
    }
	
	var accountDetails: some View {
		Section {
			TextField("Email", text: $accountEmail, prompt: Text("Email Address", comment: "Textfield for the user to enter their account email address."))
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
			.disabled(!validateCredentials())
		}
	}
	
	var feedbinAccountExplainer: some View {
		if account == nil {
			return Text("Sign in to your Feedbin account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a Feedbin account? [Sign Up Here](https://feedbin.com/signup)", comment: "Explanatory text describing the Feedbin account.")
				.multilineTextAlignment(.center)
		}
		return Text("").multilineTextAlignment(.center)
	}
	
	private func validateCredentials() -> Bool {
		if (accountEmail.trimmingWhitespace.count == 0) || (accountPassword.trimmingWhitespace.count == 0) {
			return false
		}
		return true
	}
	
	private func retrieveCredentials() {
		if let account = account {
			do {
				if let creds = try account.retrieveCredentials(type: .basic) {
					accountEmail = creds.username
					accountPassword = creds.secret
				}
			} catch {
				accountError = (error, true)
			}
		}
	}
	
	private func executeAccountCredentials() async throws {
		let trimmedEmailAddress = accountEmail.trimmingWhitespace
		
		guard (account != nil || !AccountManager.shared.duplicateServiceAccount(type: .feedbin, username: trimmedEmailAddress)) else {
			throw LocalizedNetNewsWireError.duplicateAccount
		}
		showProgressIndicator = true
		
		let credentials = Credentials(type: .basic, username: trimmedEmailAddress, secret: accountPassword)
		return try await withCheckedThrowingContinuation { continuation in
			Account.validateCredentials(type: .feedbin, credentials: credentials) { result in
				switch result {
				case .success(let credentials):
					if let validatedCredentials = credentials {
						if self.account == nil {
							self.account = AccountManager.shared.createAccount(type: .feedbin)
						}
						
						do {
							try? self.account?.removeCredentials(type: .basic)
							try self.account?.storeCredentials(validatedCredentials)
							self.account?.refreshAll(completion: { result in
								switch result {
								case .success(_):
									showProgressIndicator = false
									continuation.resume()
								case .failure(let failure):
									showProgressIndicator = false
									continuation.resume(throwing: failure)
								}
							})
						} catch {
							showProgressIndicator = false
							continuation.resume(throwing: LocalizedNetNewsWireError.keychainError)
						}
					} else {
						showProgressIndicator = false
						continuation.resume(throwing: LocalizedNetNewsWireError.invalidUsernameOrPassword)
					}
				case .failure(let failure):
					showProgressIndicator = false
					continuation.resume(throwing: failure)
				}
			}
		}
	}
	
	
}

struct FeedbinAddAccountView_Previews: PreviewProvider {
    static var previews: some View {
        FeedbinAddAccountView()
    }
}
