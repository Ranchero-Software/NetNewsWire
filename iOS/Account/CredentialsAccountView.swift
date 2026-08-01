//
//  CredentialsAccountView.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 9/18/26.
//

import SwiftUI
import RSCore
import Account
import Secrets

/// Sheet for adding a username-and-password account (Feedbin, NewsBlur, and the Reader API services) or updating its credentials.
struct CredentialsAccountView: View {

	let accountType: AccountType
	/// Non-nil when updating the credentials of an existing account.
	let account: Account?
	let didAddAccount: (() -> Void)?

	@Environment(\.dismiss) private var dismiss
	@State private var username = ""
	@State private var password = ""
	@State private var apiURLString = ""
	@State private var isPasswordVisible = false
	@State private var isValidating = false
	@State private var errorMessage: String?
	@State private var isShowingSignUp = false

	private static let passwordPlaceholder = NSLocalizedString("Password", comment: "Password field placeholder")

	var body: some View {
		NavigationStack {
			Form {
				Section {
					TextField(accountType.usernamePlaceholder, text: $username)
						.textContentType(.username)
						.keyboardType(.emailAddress)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
					passwordRow
					if accountType.needsAPIURL {
						TextField(NSLocalizedString("API URL: https://fresh.rss.net/api/greader.php", comment: "FreshRSS API Helper"), text: $apiURLString)
							.textContentType(.URL)
							.keyboardType(.URL)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
					}
				} header: {
					AccountIconHeader(accountType: accountType)
				}
				Section {
					Button(actionTitle) {
						Task {
							await submit()
						}
					}
					.frame(maxWidth: .infinity)
					.disabled(!canSubmit || isValidating)
				} footer: {
					AccountSheetFooter(text: accountType.footerText, linkTitle: accountType.signUpTitle) {
						isShowingSignUp = true
					}
				}
			}
			.navigationTitle(Text(verbatim: accountType.displayName))
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) {
						dismiss()
					}
					.disabled(isValidating)
				}
				ToolbarItem(placement: .topBarTrailing) {
					if isValidating {
						ProgressView()
					}
				}
			}
			.alert(NSLocalizedString("Error", comment: "Error"), isPresented: isShowingError) {
				Button(NSLocalizedString("OK", comment: "OK button")) {
					errorMessage = nil
				}
			} message: {
				Text(verbatim: errorMessage ?? "")
			}
			.sheet(isPresented: $isShowingSignUp) {
				if let signUpURL = accountType.signUpURL {
					SafariView(url: signUpURL)
				}
			}
			.onAppear {
				loadExistingCredentials()
			}
		}
	}

	private var passwordRow: some View {
		HStack {
			if isPasswordVisible {
				TextField(Self.passwordPlaceholder, text: $password)
					.textContentType(.password)
					.textInputAutocapitalization(.never)
					.autocorrectionDisabled()
			} else {
				SecureField(Self.passwordPlaceholder, text: $password)
					.textContentType(.password)
			}
			Button(isPasswordVisible ? NSLocalizedString("Hide", comment: "Hide password button") : NSLocalizedString("Show", comment: "Show password button")) {
				isPasswordVisible.toggle()
			}
			.buttonStyle(.borderless)
		}
		.alignmentGuide(.listRowSeparatorLeading) { dimensions in
			dimensions[.leading]
		}
	}

	private var actionTitle: String {
		account == nil ? NSLocalizedString("Add Account", comment: "Add Account") : NSLocalizedString("Update Credentials", comment: "Update Credentials")
	}

	private var canSubmit: Bool {
		let hasUsername = !username.trimmingWhitespace.isEmpty
		let hasPassword = !password.isEmpty
		let hasAPIURL = !apiURLString.trimmingWhitespace.isEmpty
		switch accountType {
		case .newsBlur:
			return hasUsername
		case .freshRSS:
			return hasUsername && hasPassword && hasAPIURL
		default:
			return hasUsername && hasPassword
		}
	}

	private var isShowingError: Binding<Bool> {
		Binding {
			errorMessage != nil
		} set: { isShowing in
			if !isShowing {
				errorMessage = nil
			}
		}
	}

	private func loadExistingCredentials() {
		guard let account, let credentials = try? account.retrieveCredentials(type: accountType.credentialsType) else {
			return
		}
		username = credentials.username
		password = credentials.secret
	}

	@MainActor private func submit() async {
		let trimmedUsername = username.trimmingWhitespace

		let endpoint: URL?
		if accountType.needsAPIURL {
			guard let apiURL = URL(string: apiURLString.trimmingWhitespace) else {
				errorMessage = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
				return
			}
			endpoint = apiURL
		} else {
			endpoint = accountType.readerEndpoint
		}

		if account == nil && AccountManager.shared.duplicateServiceAccount(type: accountType, username: trimmedUsername, endpoint: endpoint) {
			errorMessage = accountType.duplicateAccountMessage
			return
		}

		isValidating = true
		defer {
			isValidating = false
		}

		let basicCredentials = Credentials(type: accountType.credentialsType, username: trimmedUsername, secret: password)

		let validatedCredentials: Credentials?
		do {
			validatedCredentials = try await Account.validateCredentials(type: accountType, credentials: basicCredentials, endpoint: endpoint)
		} catch {
			errorMessage = error.localizedDescription
			return
		}

		guard let validatedCredentials else {
			errorMessage = accountType.invalidCredentialsMessage
			return
		}

		let account = self.account ?? AccountManager.shared.createAccount(type: accountType)

		do {
			try store(basicCredentials: basicCredentials, validatedCredentials: validatedCredentials, in: account, endpoint: endpoint)
		} catch {
			errorMessage = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
			return
		}

		account.triggerRefreshAll()
		dismiss()
		didAddAccount?()
	}

	private func store(basicCredentials: Credentials, validatedCredentials: Credentials, in account: Account, endpoint: URL?) throws {
		switch accountType {
		case .feedbin:
			try account.storeCredentials(validatedCredentials)
		case .newsBlur:
			try account.storeCredentials(basicCredentials)
			try account.storeCredentials(validatedCredentials)
		default:
			account.endpointURL = endpoint
			try account.storeCredentials(basicCredentials)
			try account.storeCredentials(validatedCredentials)
		}
	}
}

private extension AccountType {

	var credentialsType: CredentialsType {
		switch self {
		case .feedbin:
			return .basic
		case .newsBlur:
			return .newsBlurBasic
		default:
			return .readerBasic
		}
	}

	var needsAPIURL: Bool {
		self == .freshRSS
	}

	var usernamePlaceholder: String {
		switch self {
		case .feedbin:
			return NSLocalizedString("Email", comment: "Email field placeholder")
		default:
			return NSLocalizedString("Username or Email", comment: "Username field placeholder")
		}
	}

	var readerEndpoint: URL? {
		switch self {
		case .inoreader:
			return URL(string: ReaderAPIVariant.inoreader.host)
		case .bazQux:
			return URL(string: ReaderAPIVariant.bazQux.host)
		case .theOldReader:
			return URL(string: ReaderAPIVariant.theOldReader.host)
		case .wordpressCom:
			return URL(string: ReaderAPIVariant.wordpressCom.host)
		default:
			return nil
		}
	}

	var signUpURL: URL? {
		switch self {
		case .feedbin:
			return URL(string: "https://feedbin.com/signup")
		case .newsBlur:
			return URL(string: "https://newsblur.com")
		case .bazQux:
			return URL(string: "https://bazqux.com")
		case .inoreader:
			return URL(string: "https://www.inoreader.com")
		case .theOldReader:
			return URL(string: "https://theoldreader.com")
		case .freshRSS:
			return URL(string: "https://freshrss.org")
		case .wordpressCom:
			return URL(string: "https://wordpress.com/support/reader/use-a-third-party-rss-reader-with-wordpress-com/")
		default:
			return nil
		}
	}

	var signUpTitle: String {
		switch self {
		case .freshRSS, .wordpressCom:
			return NSLocalizedString("Find Out More", comment: "Find Out More")
		default:
			return NSLocalizedString("Sign Up Here", comment: "Sign Up")
		}
	}

	var footerText: String {
		switch self {
		case .feedbin:
			return NSLocalizedString("Sign in to your Feedbin account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a Feedbin account?", comment: "Feedbin")
		case .newsBlur:
			return NSLocalizedString("Sign in to your NewsBlur account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a NewsBlur account?", comment: "NewsBlur")
		case .bazQux:
			return NSLocalizedString("Sign in to your BazQux account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a BazQux account?", comment: "BazQux")
		case .inoreader:
			return NSLocalizedString("Sign in to your Inoreader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an Inoreader account?", comment: "Inoreader")
		case .theOldReader:
			return NSLocalizedString("Sign in to your The Old Reader account and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have a The Old Reader account?", comment: "TOR")
		case .freshRSS:
			return NSLocalizedString("Sign in to your FreshRSS instance and sync your feeds across your devices. Your username and password will be encrypted and stored in Keychain.\n\nDon’t have an FreshRSS instance?", comment: "FreshRSS")
		case .wordpressCom:
			return NSLocalizedString("Sign in with your WordPress.com username and an application password to sync your feeds across your devices. Your credentials will be encrypted and stored in Keychain.\n\nNeed to set up an application password?", comment: "WordPress.com")
		default:
			return ""
		}
	}

	var duplicateAccountMessage: String {
		switch self {
		case .feedbin:
			return NSLocalizedString("There is already a Feedbin account with that username created.", comment: "Duplicate Error")
		case .newsBlur:
			return NSLocalizedString("There is already a NewsBlur account with that username created.", comment: "Duplicate Error")
		default:
			return NSLocalizedString("There is already an account of that type with that username created.", comment: "Duplicate Error")
		}
	}

	var invalidCredentialsMessage: String {
		switch self {
		case .feedbin:
			return NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
		default:
			return NSLocalizedString("Invalid username/password combination.", comment: "Credentials Error")
		}
	}
}
