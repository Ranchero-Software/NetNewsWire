//
//  AccountsMinifluxWindowController.swift
//  NetNewsWire
//
//  Created by Dave Marquard on 7/15/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSWeb
import Secrets

final class AccountsMinifluxWindowController: NSWindowController {

	@IBOutlet var titleImageView: NSImageView?
	@IBOutlet var titleLabel: NSTextField?

	@IBOutlet var gridView: NSGridView?
	@IBOutlet var progressIndicator: NSProgressIndicator?
	@IBOutlet var usernameTextField: NSTextField?
	@IBOutlet var apiURLTextField: NSTextField?
	@IBOutlet var passwordTextField: NSSecureTextField?
	@IBOutlet var apiTokenTextField: NSSecureTextField?
	@IBOutlet var authModeControl: NSSegmentedControl?
	@IBOutlet var createAccountButton: NSButton?
	@IBOutlet var errorMessageLabel: NSTextField?
	@IBOutlet var actionButton: NSButton?
	@IBOutlet var noAccountTextField: NSTextField?

	var account: Account?

	private weak var hostWindow: NSWindow?

	private let usernameRowIndex = 1
	private let passwordRowIndex = 2
	private let apiTokenRowIndex = 3

	private enum AuthMode: Int {
		case usernameAndPassword = 0
		case apiToken = 1
	}

	private var isTokenMode: Bool {
		authModeControl?.selectedSegment == AuthMode.apiToken.rawValue
	}

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsMiniflux"))
	}

	override func windowDidLoad() {
		titleImageView?.image = Assets.Images.accountMiniflux
		titleLabel?.stringValue = NSLocalizedString("Sign in to your Miniflux account.", comment: "Sign in to your Miniflux account.")
		noAccountTextField?.stringValue = NSLocalizedString("Don’t have a Miniflux instance?", comment: "Don’t have a Miniflux instance?")
		createAccountButton?.title = NSLocalizedString("Find out more", comment: "Find out more")
		apiURLTextField?.placeholderString = NSLocalizedString("https://miniflux.example.com", comment: "Miniflux API Helper")

		authModeControl?.setLabel(NSLocalizedString("Username and Password", comment: "Username and Password"), forSegment: AuthMode.usernameAndPassword.rawValue)
		authModeControl?.setLabel(NSLocalizedString("API Token", comment: "API Token"), forSegment: AuthMode.apiToken.rawValue)
		authModeControl?.selectedSegment = AuthMode.usernameAndPassword.rawValue

		if let account {
			if let tokenCredentials = try? account.retrieveCredentials(type: .minifluxAPIToken) {
				apiTokenTextField?.stringValue = tokenCredentials.secret
				authModeControl?.selectedSegment = AuthMode.apiToken.rawValue
			} else if let basicCredentials = try? account.retrieveCredentials(type: .minifluxBasic) {
				usernameTextField?.stringValue = basicCredentials.username
				authModeControl?.selectedSegment = AuthMode.usernameAndPassword.rawValue
			}
			apiURLTextField?.stringValue = account.endpointURL?.absoluteString ?? ""
			actionButton?.title = NSLocalizedString("Update", comment: "Update")
		} else {
			actionButton?.title = NSLocalizedString("Add", comment: "Add button")
		}

		updateAuthModeVisibility()
		enableAutofill()
		apiURLTextField?.becomeFirstResponder()
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
		guard let hostWindow, let window else {
			return
		}
		hostWindow.endSheet(window, returnCode: NSApplication.ModalResponse.cancel)
	}

	@IBAction func action(_ sender: Any) {
		errorMessageLabel?.stringValue = ""

		guard let apiURL = Miniflux.normalizedEndpointURL(from: apiURLTextField?.stringValue ?? "") else {
			errorMessageLabel?.stringValue = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
			return
		}

		let credentials: Credentials

		if isTokenMode {
			let token = apiTokenTextField?.stringValue.trimmingWhitespace ?? ""
			guard !token.isEmpty else {
				errorMessageLabel?.stringValue = NSLocalizedString("An API token is required.", comment: "Credentials Error")
				return
			}
			credentials = Credentials(type: .minifluxAPIToken, username: "", secret: token)
		} else {
			let trimmedUsername = usernameTextField?.stringValue.trimmingWhitespace ?? ""
			let password = passwordTextField?.stringValue ?? ""
			guard !trimmedUsername.isEmpty, !password.isEmpty else {
				errorMessageLabel?.stringValue = NSLocalizedString("Username and password are required.", comment: "Credentials Error")
				return
			}
			credentials = Credentials(type: .minifluxBasic, username: trimmedUsername, secret: password)
		}

		Task { @MainActor in
			actionButton?.isEnabled = false
			progressIndicator?.isHidden = false
			progressIndicator?.startAnimation(self)

			@MainActor func stopAnimation() {
				actionButton?.isEnabled = true
				progressIndicator?.isHidden = true
				progressIndicator?.stopAnimation(self)
			}

			do {
				let validatedCredentials = try await Account.validateCredentials(type: .miniflux, credentials: credentials, endpoint: apiURL)
				stopAnimation()

				guard let validatedCredentials else {
					errorMessageLabel?.stringValue = NSLocalizedString("Invalid username/password combination, or invalid API token.", comment: "Credentials Error")
					return
				}

				guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .miniflux, username: validatedCredentials.username, endpoint: apiURL) else {
					errorMessageLabel?.stringValue = NSLocalizedString("There is already a Miniflux account for this user on this server.", comment: "Duplicate Error")
					return
				}

				let isNewAccount = account == nil
				if isNewAccount {
					account = AccountManager.shared.createAccount(type: .miniflux)
				}

				do {
					// The Keychain key comes from the endpoint and username, so remove the old credentials before either changes.
					try? account?.removeCredentials(type: .minifluxBasic)
					try? account?.removeCredentials(type: .minifluxAPIToken)
					account?.endpointURL = apiURL
					try account?.storeCredentials(validatedCredentials)

					if let hostWindow, let window {
						hostWindow.endSheet(window, returnCode: NSApplication.ModalResponse.OK)
					}

					let refreshingAccount = account
					Task { @MainActor in
						do {
							try await refreshingAccount?.refreshAll()
						} catch {
							NSApplication.shared.presentError(error)
						}
					}
				} catch {
					if isNewAccount, let account {
						AccountManager.shared.deleteAccount(account)
						self.account = nil
					}
					errorMessageLabel?.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}

			} catch {
				stopAnimation()
				errorMessageLabel?.stringValue = error.localizedDescription
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {
		guard let url = URL(string: "https://miniflux.app") else {
			return
		}
		NSWorkspace.shared.open(url)
	}

	@IBAction func authModeChanged(_ sender: Any) {
		updateAuthModeVisibility()
	}

	// MARK: Autofill

	func enableAutofill() {
		usernameTextField?.contentType = .username
		passwordTextField?.contentType = .password
	}

	// MARK: Auth Mode

	private func updateAuthModeVisibility() {
		gridView?.row(at: usernameRowIndex).isHidden = isTokenMode
		gridView?.row(at: passwordRowIndex).isHidden = isTokenMode
		gridView?.row(at: apiTokenRowIndex).isHidden = !isTokenMode
	}
}
