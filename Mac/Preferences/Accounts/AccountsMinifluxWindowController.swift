//
//  AccountsMinifluxWindowController.swift
//  NetNewsWire
//
//  Created by Ingmar Stein on 6/18/26.
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
	@IBOutlet var apiURLTextField: NSTextField!
	@IBOutlet var apiKeyTextField: NSSecureTextField!
	@IBOutlet var createAccountButton: NSButton!
	@IBOutlet var errorMessageLabel: NSTextField!
	@IBOutlet var actionButton: NSButton!
	@IBOutlet var noAccountTextField: NSTextField!

	var account: Account?
	var accountType: AccountType?

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsMiniflux"))
	}

	override func windowDidLoad() {
		titleImageView.image = Assets.Images.accountMiniflux
		titleLabel.stringValue = NSLocalizedString("Sign in to your Miniflux instance.", comment: "Miniflux")
		noAccountTextField.stringValue = NSLocalizedString("Don't have a Miniflux instance?", comment: "No Miniflux")
		createAccountButton.title = NSLocalizedString("Find out more", comment: "No Miniflux Button")
		apiURLTextField.placeholderString = NSLocalizedString("https://miniflux.example.com", comment: "Miniflux API URL Helper")

		if let account = account, let credentials = try? account.retrieveCredentials(type: .minifluxAPIKey) {
			apiURLTextField.stringValue = account.endpointURL?.absoluteString ?? ""
			apiKeyTextField.stringValue = credentials.secret
			actionButton.title = NSLocalizedString("Update", comment: "Update")
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
		}

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
		self.errorMessageLabel.stringValue = ""

		guard !apiURLTextField.stringValue.isEmpty && !apiKeyTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = NSLocalizedString("API URL and API Key are required.", comment: "Credentials Error")
			return
		}

		let accountType: AccountType = .miniflux

		guard let inputURL = URL(string: apiURLTextField.stringValue.trimmingWhitespace) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Invalid API URL.", comment: "Invalid API URL")
			return
		}
		let apiURL = inputURL

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: accountType, endpointURL: apiURL) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("There is already a Miniflux account with that URL created.", comment: "Duplicate Error")
			return
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

			let trimmedAPIKey = apiKeyTextField.stringValue.trimmingWhitespace
			let credentials = Credentials(type: .minifluxAPIKey, username: trimmedAPIKey, secret: trimmedAPIKey)
			do {
				let validatedCredentials = try await Account.validateCredentials(type: accountType, credentials: credentials, endpoint: apiURL)
				stopAnimation()

				guard let validatedCredentials else {
					errorMessageLabel.stringValue = NSLocalizedString("Invalid API key.", comment: "Credentials Error")
					return
				}

				if account == nil {
					account = AccountManager.shared.createAccount(type: accountType)
				}

				do {
					account?.endpointURL = apiURL

					try account?.storeCredentials(validatedCredentials)

					do {
						try await account?.refreshAll()
					} catch {
						NSApplication.shared.presentError(error)
					}

					hostWindow?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
				} catch {
					errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}

			} catch {
				stopAnimation()
				if case AccountError.urlNotFound = error {
					errorMessageLabel.stringValue = NSLocalizedString("The API URL couldn't be found. Please check the URL.", comment: "API URL not found")
				} else {
					errorMessageLabel.stringValue = error.localizedDescription
				}
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {
		NSWorkspace.shared.open(URL(string: "https://miniflux.app")!)
	}
}
