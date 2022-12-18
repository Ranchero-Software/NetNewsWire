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
					Button(action: { dismiss() }, label: { Text("CANCEL_BUTTON_TITLE", tableName: "Buttons") })
						.disabled(showProgressIndicator)
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					if showProgressIndicator { ProgressView() }
				}
			}
			.alert(Text("ERROR_TITLE", tableName: "Errors"), isPresented: $accountError.1) {
				Button(role: .cancel) {
					//
				} label: {
					Text("DISMISS_BUTTON_TITLE", tableName: "Buttons")
				}
			} message: {
				Text(accountError.0?.localizedDescription ?? "Error")
			}
			.navigationTitle(Text(account?.type.localizedAccountName() ?? ""))
			.navigationBarTitleDisplayMode(.inline)
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
    }
	
	var accountDetails: some View {
		Section {
			TextField("Email", text: $accountEmail, prompt: Text("ACCOUNT_EMAIL_ADDRESS_PROMPT", tableName: "Account"))
				.autocorrectionDisabled()
				.autocapitalization(.none)
			SecureField("Password", text: $accountPassword, prompt: Text("ACCOUNT_PASSWORD_PROMPT", tableName: "Account"))
		}
	}
	
	var accountButton: some View {
		Section {
			Button {
				Task {
					do {
						try await executeAccountCredentials()
						dismiss()
					} catch {
						accountError = (error, true)
					}
				}
			} label: {
				HStack{
					Spacer()
					if account == nil {
						Text("ADD_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
					} else {
						Text("UPDATE_CREDENTIALS_BUTTON_TITLE", tableName: "Buttons")
					}
					Spacer()
				}
			}
		}
	}
	
	var feedbinAccountExplainer: some View {
		Text("FEEDBIN_FOOTER_EXPLAINER", tableName: "Account").multilineTextAlignment(.center)
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
