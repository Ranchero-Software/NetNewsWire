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

struct ReaderAPIAccountView: View {
	
	@Environment(\.dismiss) var dismiss
	
	var accountType: AccountType?
	@State var account: Account?
	@State private var accountCredentials: Credentials?
	@State private var accountUserName: String = ""
	@State private var accountSecret: String = ""
	@State private var accountAPIUrl: String = ""
	@State private var showProgressIndicator: Bool = false
	@State private var accountSetupError: (Error?, Bool) = (nil, false)
	
	var body: some View {
		NavigationView {
			Form {
				Section(header: readerAccountImage) {}
				accountDetailsSection
				Section(footer: readerAccountExplainer) {}
			}
			.navigationTitle(Text(accountType?.localizedAccountName() ?? ""))
			.navigationBarTitleDisplayMode(.inline)
			.task {
				try? retrieveAccountCredentials()
			}
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button(action: { dismiss() }, label: { Text("CANCEL_BUTTON_TITLE", tableName: "Buttons") })
				}
				ToolbarItem(placement: .navigationBarTrailing) {
					if showProgressIndicator { ProgressView() }
				}
			}
			.alert(Text("ERROR_TITLE", tableName: "Errors"), isPresented: $accountSetupError.1) {
				Button(role: .cancel) {
					//
				} label: {
					Text("DISMISS_BUTTON_TITLE", tableName: "Buttons")
				}
			} message: {
				Text(accountSetupError.0?.localizedDescription ?? "")
			}
			.onReceive(NotificationCenter.default.publisher(for: .UserDidAddAccount)) { _ in
				dismiss()
			}
			.edgesIgnoringSafeArea(.bottom) // Fix to make sure view is not offset from the top when presented
		}
	}
	
	var readerAccountExplainer: some View {
		if accountType == nil { return Text("").multilineTextAlignment(.center) }
		switch accountType! {
		case .bazQux:
			return Text("BAZQUX_FOOTER_EXPLAINER", tableName: "Account").multilineTextAlignment(.center)
		case .inoreader:
			return Text("INOREADER_FOOTER_EXPLAINER", tableName: "Account").multilineTextAlignment(.center)
		case .theOldReader:
			return Text("OLDREADER_FOOTER_EXPLAINER", tableName: "Account").multilineTextAlignment(.center)
		case .freshRSS:
			return Text("FRESHRSS_FOOTER_EXPLAINER", tableName: "Account").multilineTextAlignment(.center)
		default:
			return Text("").multilineTextAlignment(.center)
		}
	}
	
	var readerAccountImage: some View {
		HStack {
			Spacer()
			if accountType == nil { Text("") }
			switch accountType! {
			case .bazQux:
				Image(uiImage: AppAssets.accountBazQuxImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 48, height: 48)
			case .inoreader:
				Image(uiImage: AppAssets.accountInoreaderImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 48, height: 48)
			case .theOldReader:
				Image(uiImage: AppAssets.accountTheOldReaderImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 48, height: 48)
			case .freshRSS:
				Image(uiImage: AppAssets.accountFreshRSSImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 48, height: 48)
			default:
				Text("")
			}
			Spacer()
		}
	}
	
	var accountDetailsSection: some View {
		Group {
			Section {
				TextField("Username", text: $accountUserName)
					.autocorrectionDisabled()
				SecureField("Password", text: $accountSecret)
				if accountType == .freshRSS && accountCredentials == nil {
					TextField("FreshRSS URL", text: $accountAPIUrl, prompt: Text("fresh.rss.net/api/greader.php"))
						.autocorrectionDisabled()
				}
			}
			
			Section {
				Button {
					Task {
						do {
							try await executeAccountCredentials()
						} catch {
							accountSetupError = (error, true)
						}
					}
				} label: {
					HStack {
						Spacer()
						if accountCredentials == nil {
							Text("ADD_ACCOUNT_BUTTON_TITLE", tableName: "Buttons")
						} else {
							Text("UPDATE_CREDENTIALS_BUTTON_TITLE", tableName: "Buttons")
						}
						Spacer()
					}
				}
				.disabled(!validateCredentials())
			}
		}
		
	}
	
	// MARK: - API
	
	private func retrieveAccountCredentials() throws {
		if let account = account {
			do {
				if let creds = try account.retrieveCredentials(type: .readerBasic) {
					self.accountCredentials = creds
					accountUserName = creds.username
					accountSecret = creds.secret
				}
			} catch {
				accountSetupError = (error, true)
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
	
	@MainActor
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
								case .failure(let error):
									showProgressIndicator = false
									continuation.resume(throwing: error)
								}
							})
						} catch {
							showProgressIndicator = false
							continuation.resume(throwing: error)
						}
					}
				case .failure(let failure):
					showProgressIndicator = false
					continuation.resume(throwing: failure)
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
		ReaderAPIAccountView()
	}
}
