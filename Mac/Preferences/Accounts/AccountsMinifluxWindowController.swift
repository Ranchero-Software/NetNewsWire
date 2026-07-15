//
//  AccountsMinifluxWindowController.swift
//  NetNewsWire
//
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSWeb
import Secrets

final class AccountsMinifluxWindowController: NSWindowController {

	@IBOutlet var titleImageView: NSImageView!
	@IBOutlet var titleLabel: NSTextField!

	@IBOutlet var gridView: NSGridView!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var usernameTextField: NSTextField!
	@IBOutlet var apiURLTextField: NSTextField!
	@IBOutlet var passwordTextField: NSSecureTextField!
	@IBOutlet var apiTokenTextField: NSSecureTextField!
	@IBOutlet var authModeControl: NSSegmentedControl!
	@IBOutlet var createAccountButton: NSButton!
	@IBOutlet var errorMessageLabel: NSTextField!
	@IBOutlet var actionButton: NSButton!
	@IBOutlet var noAccountTextField: NSTextField!

	var account: Account?

	private weak var hostWindow: NSWindow?

	/// Fixed row indices in `gridView`: API URL, Username, Password, API Token.
	private let usernameRowIndex = 1
	private let passwordRowIndex = 2
	private let apiTokenRowIndex = 3

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsMiniflux"))
	}

	override func windowDidLoad() {
		titleImageView.image = Assets.Images.accountMiniflux
		titleLabel.stringValue = NSLocalizedString("Sign in to your Miniflux account.", comment: "Miniflux")
		noAccountTextField.stringValue = NSLocalizedString("Don’t have a Miniflux instance?", comment: "No Miniflux")
		createAccountButton.title = NSLocalizedString("Find out more", comment: "No Miniflux Button")
		apiURLTextField.placeholderString = NSLocalizedString("https://miniflux.example.com", comment: "Miniflux API Helper")

		authModeControl.selectedSegment = 0

		if let account {
			if let tokenCredentials = try? account.retrieveCredentials(type: .minifluxAPIToken) {
				apiTokenTextField.stringValue = tokenCredentials.secret
				authModeControl.selectedSegment = 1
			} else if let basicCredentials = try? account.retrieveCredentials(type: .minifluxBasic) {
				usernameTextField.stringValue = basicCredentials.username
				authModeControl.selectedSegment = 0
			}
			apiURLTextField.stringValue = account.endpointURL?.absoluteString ?? ""
			actionButton.title = NSLocalizedString("Update", comment: "Update")
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
		}

		updateAuthModeVisibility()
		enableAutofill()
		apiURLTextField.becomeFirstResponder()
	}

	// MARK: API

	func runSheetOnWindow(_ hostWindow: NSWindow, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		guard let window else {
			return
		}

		self.hostWindow = hostWindow
		hostWindow.beginSheet(window, completionHandler: completion)
	}

	// MARK: Actions

	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}

	@IBAction func action(_ sender: Any) {
		errorMessageLabel.stringValue = ""

		guard let apiURL = normalizedEndpointURL(from: apiURLTextField.stringValue) else {
			errorMessageLabel.stringValue = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
			return
		}

		let isTokenMode = authModeControl.selectedSegment == 1
		let credentials: Credentials

		if isTokenMode {
			let token = apiTokenTextField.stringValue.trimmingWhitespace
			guard !token.isEmpty else {
				errorMessageLabel.stringValue = NSLocalizedString("An API token is required.", comment: "Credentials Error")
				return
			}
			credentials = Credentials(type: .minifluxAPIToken, username: "", secret: token)
		} else {
			let trimmedUsername = usernameTextField.stringValue.trimmingWhitespace
			let password = passwordTextField.stringValue
			guard !trimmedUsername.isEmpty, !password.isEmpty else {
				errorMessageLabel.stringValue = NSLocalizedString("Username and password are required.", comment: "Credentials Error")
				return
			}
			credentials = Credentials(type: .minifluxBasic, username: trimmedUsername, secret: password)
		}

		Task { @MainActor in
			actionButton.isEnabled = false
			progressIndicator.isHidden = false
			progressIndicator.startAnimation(self)

			@MainActor func stopAnimation() {
				actionButton.isEnabled = true
				progressIndicator.isHidden = true
				progressIndicator.stopAnimation(self)
			}

			do {
				let validatedCredentials = try await Account.validateCredentials(type: .miniflux, credentials: credentials, endpoint: apiURL)
				stopAnimation()

				guard let validatedCredentials else {
					errorMessageLabel.stringValue = NSLocalizedString("Invalid username/password combination, or invalid API token.", comment: "Credentials Error")
					return
				}

				guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, username: validatedCredentials.username) else {
					errorMessageLabel.stringValue = NSLocalizedString("There is already an account of this type with that username created.", comment: "Duplicate Error")
					return
				}

				guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, endpointURL: apiURL) else {
					errorMessageLabel.stringValue = NSLocalizedString("There is already a Miniflux account for this server.", comment: "Duplicate Error")
					return
				}

				if account == nil {
					account = AccountManager.shared.createAccount(type: .miniflux)
				}

				do {
					account?.endpointURL = apiURL

					// Remove any credentials of the other type so a stale token or
					// password doesn't take precedence after switching auth modes.
					let staleCredentialsType: CredentialsType = validatedCredentials.type == .minifluxAPIToken ? .minifluxBasic : .minifluxAPIToken
					try? account?.removeCredentials(type: staleCredentialsType)
					try account?.storeCredentials(validatedCredentials)

					hostWindow?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)

					let refreshingAccount = account
					Task { @MainActor in
						do {
							try await refreshingAccount?.refreshAll()
						} catch {
							NSApplication.shared.presentError(error)
						}
					}
				} catch {
					errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}

			} catch {
				stopAnimation()
				errorMessageLabel.stringValue = error.localizedDescription
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {
		NSWorkspace.shared.open(URL(string: "https://miniflux.app")!)
	}

	@IBAction func authModeChanged(_ sender: Any) {
		updateAuthModeVisibility()
	}

	// MARK: Autofill

	func enableAutofill() {
		usernameTextField.contentType = .username
		passwordTextField.contentType = .password
	}

	// MARK: Auth Mode

	private func updateAuthModeVisibility() {
		let isTokenMode = authModeControl.selectedSegment == 1
		gridView.row(at: usernameRowIndex).isHidden = isTokenMode
		gridView.row(at: passwordRowIndex).isHidden = isTokenMode
		gridView.row(at: apiTokenRowIndex).isHidden = !isTokenMode
	}

	// MARK: URL Normalization

	/// Trims whitespace, adds a `https://` scheme if none was given, drops a
	/// trailing slash, and strips a trailing `/v1` path component in case the
	/// user pasted the API URL rather than the instance's base URL —
	/// e.g. `https://host/v1/` becomes `https://host`.
	private func normalizedEndpointURL(from string: String) -> URL? {
		var trimmed = string.trimmingWhitespace
		guard !trimmed.isEmpty else {
			return nil
		}

		if !trimmed.contains("://") {
			trimmed = "https://" + trimmed
		}

		if trimmed.hasSuffix("/") {
			trimmed = String(trimmed.dropLast())
		}
		if trimmed.hasSuffix("/v1") {
			trimmed = String(trimmed.dropLast(3))
		}
		if trimmed.hasSuffix("/") {
			trimmed = String(trimmed.dropLast())
		}

		guard !trimmed.isEmpty else {
			return nil
		}

		return URL(string: trimmed)
	}

}
