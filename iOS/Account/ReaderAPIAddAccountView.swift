//
//  ReaderAPIAccountView.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 16/12/2022.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import SwiftUI
import Account
import Secrets
import RSWeb
import SafariServices
import RSCore

struct ReaderAPIAddAccountView: View {
	
	@Environment(\.dismiss) var dismiss
	
	var accountType: AccountType?
	@State var account: Account?
	@State private var accountCredentials: Credentials?
	@State private var accountUserName: String = ""
	@State private var accountSecret: String = ""
	@State private var accountAPIUrl: String = ""
	@State private var showProgressIndicator: Bool = false
	@State private var accountError: (Error?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			Form {
				if accountType != nil {
					AccountSectionHeader(accountType: accountType!)
				}
				accountDetails
				accountButton
				Section(footer: readerAccountExplainer) {}
			}
			.navigationTitle(Text(accountType?.localizedAccountName() ?? ""))
			.navigationBarTitleDisplayMode(.inline)
			.task {
				retrieveAccountCredentials()
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
				Text(accountError.0?.localizedDescription ?? "")
			}
			.interactiveDismissDisabled(showProgressIndicator)
			.dismissOnExternalContextLaunch()
			.dismissOnAccountAdd()
		}
	}
	
	var readerAccountExplainer: some View {
		if accountType == nil { return Text("").multilineTextAlignment(.center) }
		switch accountType! {
		case .bazQux:
			return Text("Sign in to your BazQux account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a BazQux account? [Sign Up Here](https://bazqux.com)", comment: "Explanatory text describing the BazQux account").multilineTextAlignment(.center)
		case .inoreader:
			return Text("Sign in to your InoReader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an InoReader account? [Sign Up Here](https://www.inoreader.com)", comment: "Explanatory text describing the Inoreader account").multilineTextAlignment(.center)
		case .theOldReader:
			return Text("Sign in to your The Old Reader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a The Old Reader account? [Sign Up Here](https://theoldreader.com)", comment: "Explanatory text describing The Old Reader account").multilineTextAlignment(.center)
		case .freshRSS:
			return Text("Sign in to your FreshRSS instance and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an FreshRSS instance? [Sign Up Here](https://freshrss.org)", comment: "Explanatory text describing the FreshRSS account").multilineTextAlignment(.center)
		default:
			return Text("").multilineTextAlignment(.center)
		}
	}
	
	
	
	var accountDetails: some View {
		Section {
			TextField("Username", text: $accountUserName)
				.autocorrectionDisabled()
				.autocapitalization(.none)
				.textContentType(.username)
			SecureField("Password", text: $accountSecret)
				.textContentType(.password)
			if accountType == .freshRSS && accountCredentials == nil {
				TextField("FreshRSS URL", text: $accountAPIUrl, prompt: Text("fresh.rss.net/api/greader.php"))
					.autocorrectionDisabled()
					.autocapitalization(.none)
			}
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
				HStack {
					Spacer()
					if accountCredentials == nil {
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
	
	// MARK: - API
	
	private func retrieveAccountCredentials() {
		if let account = account {
			do {
				if let creds = try account.retrieveCredentials(type: .readerBasic) {
					self.accountCredentials = creds
					accountUserName = creds.username
					accountSecret = creds.secret
				}
			} catch {
				accountError = (error, true)
			}
		}
	}
	
	private func validateCredentials() -> Bool {
		if accountType == nil { return false }
		switch accountType! {
		case .freshRSS:
			if (accountUserName.trimmingWhitespace.count == 0) || (accountSecret.trimmingWhitespace.count == 0) || (accountAPIUrl.trimmingWhitespace.count == 0) {
				return false
			}
		default:
			if (accountUserName.trimmingWhitespace.count == 0) || (accountSecret.trimmingWhitespace.count == 0) {
				return false
			}
		}
		return true
	}
	
	private func executeAccountCredentials() async throws {
		
		let trimmedAccountUserName = accountUserName.trimmingWhitespace
		
		guard (account != nil || !AccountManager.shared.duplicateServiceAccount(type: accountType!, username: trimmedAccountUserName)) else {
			throw LocalizedNetNewsWireError.duplicateAccount
		}
		
		showProgressIndicator = true
		let credentials = Credentials(type: .readerBasic, username: trimmedAccountUserName, secret: accountSecret)
		
		return try await withCheckedThrowingContinuation { continuation in
			Account.validateCredentials(type: accountType!, credentials: credentials, endpoint: apiURL()) { result in
				switch result {
				case .success(let validatedCredentials):
					if let validatedCredentials = validatedCredentials {
						if self.account == nil {
							self.account = AccountManager.shared.createAccount(type: accountType!)
						}
						
						do {
							self.account?.endpointURL = apiURL()
							try? self.account?.removeCredentials(type: .readerBasic)
							try? self.account?.removeCredentials(type: .readerAPIKey)
							try self.account?.storeCredentials(credentials)
							try self.account?.storeCredentials(validatedCredentials)
							
							self.account?.refreshAll(completion: { result in
								switch result {
								case .success:
									showProgressIndicator = false
									continuation.resume()
									return
								case .failure(let error):
									showProgressIndicator = false
									continuation.resume(throwing: error)
									return
								}
							})
						} catch {
							showProgressIndicator = false
							continuation.resume(throwing: LocalizedNetNewsWireError.keychainError)
							return
						}
					}
				case .failure(let failure):
					showProgressIndicator = false
					continuation.resume(throwing: failure)
					return
				}
			}
		}
	}
	
	private func apiURL() -> URL? {
		switch accountType! {
		case .freshRSS:
			return URL(string: accountAPIUrl)!
		case .inoreader:
			return URL(string: ReaderAPIVariant.inoreader.host)!
		case .bazQux:
			return URL(string: ReaderAPIVariant.bazQux.host)!
		case .theOldReader:
			return URL(string: ReaderAPIVariant.theOldReader.host)!
		default:
			return nil
		}
	}
	
}

struct ReaderAPIAccountView_Previews: PreviewProvider {
	static var previews: some View {
		ReaderAPIAddAccountView()
	}
}
