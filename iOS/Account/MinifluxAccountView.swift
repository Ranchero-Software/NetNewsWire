//
//  MinifluxAccountView.swift
//  NetNewsWire-iOS
//
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import SwiftUI
import RSCore
import Account
import Secrets

/// Miniflux supports either a username and password or an API token.
struct MinifluxAccountView: View {

	let account: Account?
	let didAddAccount: (() -> Void)?

	@Environment(\.dismiss) private var dismiss
	@State private var username = ""
	@State private var password = ""
	@State private var apiToken = ""
	@State private var apiURLString = ""
	@State private var usesAPIToken = false
	@State private var isValidating = false
	@State private var errorMessage: String?
	@State private var isShowingSignUp = false

	var body: some View {
		NavigationStack {
			Form {
				Section {
					Picker(NSLocalizedString("Authentication", comment: "Miniflux authentication mode"), selection: $usesAPIToken) {
						Text(NSLocalizedString("Username and Password", comment: "Miniflux authentication mode")).tag(false)
						Text(NSLocalizedString("API Token", comment: "Miniflux authentication mode")).tag(true)
					}
					if usesAPIToken {
						SecureField(NSLocalizedString("API Token", comment: "Miniflux API token"), text: $apiToken)
					} else {
						TextField(NSLocalizedString("Username or Email", comment: "Username field placeholder"), text: $username)
							.textContentType(.username)
							.textInputAutocapitalization(.never)
							.autocorrectionDisabled()
						SecureField(NSLocalizedString("Password", comment: "Password field placeholder"), text: $password)
					}
					TextField(NSLocalizedString("API URL: https://miniflux.example.com", comment: "Miniflux API Helper"), text: $apiURLString)
						.textContentType(.URL)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
				} header: {
					AccountIconHeader(accountType: .miniflux)
				}
				Section {
					Button(account == nil ? NSLocalizedString("Add Account", comment: "Add Account") : NSLocalizedString("Update Credentials", comment: "Update Credentials")) {
						Task { await submit() }
					}
					.frame(maxWidth: .infinity)
					.disabled(!canSubmit || isValidating)
				} footer: {
					AccountSheetFooter(text: NSLocalizedString("Sign in to your Miniflux instance and sync your feeds across your devices. Your credentials will be encrypted and stored in Keychain.\n\nDon’t have a Miniflux instance?", comment: "Miniflux"), linkTitle: NSLocalizedString("Find Out More", comment: "Find Out More")) {
						isShowingSignUp = true
					}
				}
			}
			.navigationTitle("Miniflux")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) { dismiss() }
						.disabled(isValidating)
				}
				ToolbarItem(placement: .topBarTrailing) {
					if isValidating { ProgressView() }
				}
			}
			.alert(NSLocalizedString("Error", comment: "Error"), isPresented: isShowingError) {
				Button(NSLocalizedString("OK", comment: "OK button")) { errorMessage = nil }
			} message: {
				Text(verbatim: errorMessage ?? "")
			}
			.sheet(isPresented: $isShowingSignUp) {
				SafariView(url: URL(string: "https://miniflux.app")!)
			}
			.onAppear { loadExistingCredentials() }
		}
	}

	private var canSubmit: Bool {
		guard !apiURLString.trimmingWhitespace.isEmpty else { return false }
		return usesAPIToken
			? !apiToken.trimmingWhitespace.isEmpty
			: !username.trimmingWhitespace.isEmpty && !password.isEmpty
	}

	private var isShowingError: Binding<Bool> {
		Binding {
			errorMessage != nil
		} set: { isShowing in
			if !isShowing { errorMessage = nil }
		}
	}

	private func loadExistingCredentials() {
		guard let account else { return }
		apiURLString = account.endpointURL?.absoluteString ?? ""
		if let credentials = try? account.retrieveCredentials(type: .minifluxAPIToken) {
			usesAPIToken = true
			apiToken = credentials.secret
		} else if let credentials = try? account.retrieveCredentials(type: .minifluxBasic) {
			username = credentials.username
			password = credentials.secret
		}
	}

	@MainActor private func submit() async {
		guard let endpoint = normalizedEndpointURL else {
			errorMessage = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
			return
		}
		if account == nil && AccountManager.shared.duplicateServiceAccount(type: .miniflux, endpointURL: endpoint) {
			errorMessage = NSLocalizedString("There is already a Miniflux account for this server.", comment: "Duplicate Error")
			return
		}

		let credentials = usesAPIToken
			? Credentials(type: .minifluxAPIToken, username: "", secret: apiToken.trimmingWhitespace)
			: Credentials(type: .minifluxBasic, username: username.trimmingWhitespace, secret: password)

		isValidating = true
		defer { isValidating = false }

		do {
			guard let validatedCredentials = try await Account.validateCredentials(type: .miniflux, credentials: credentials, endpoint: endpoint) else {
				errorMessage = NSLocalizedString("Invalid username/password combination, or invalid API token.", comment: "Credentials Error")
				return
			}

			let account = self.account ?? AccountManager.shared.createAccount(type: .miniflux)
			account.endpointURL = endpoint
			let staleType: CredentialsType = validatedCredentials.type == .minifluxAPIToken ? .minifluxBasic : .minifluxAPIToken
			try? account.removeCredentials(type: staleType)
			try account.storeCredentials(validatedCredentials)

			account.triggerRefreshAll()
			dismiss()
			didAddAccount?()
		} catch {
			errorMessage = error.localizedDescription
		}
	}

	private var normalizedEndpointURL: URL? {
		var text = apiURLString.trimmingWhitespace
		while text.hasSuffix("/") { text.removeLast() }
		if text.hasSuffix("/v1") { text.removeLast(3) }
		while text.hasSuffix("/") { text.removeLast() }
		guard !text.isEmpty else { return nil }
		if !text.contains("://") { text = "https://" + text }
		return URL(string: text)
	}
}
