//
//  AccountsAddFeedbinWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore
import RSWeb
import Secrets

@MainActor class AccountsFeedbinWindowController: NSWindowController, Logging {

	@IBOutlet weak var signInTextField: NSTextField!
	@IBOutlet weak var noAccountTextField: NSTextField!
	@IBOutlet weak var createNewAccountButton: NSButton!
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var usernameTextField: NSTextField!
	@IBOutlet weak var passwordTextField: NSSecureTextField!
	@IBOutlet weak var errorMessageLabel: NSTextField!
	@IBOutlet weak var actionButton: NSButton!
	
	var account: Account?
	
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsFeedbin"))
	}
	
	override func windowDidLoad() {
		if let account = account, let credentials = try? account.retrieveCredentials(type: .basic) {
			usernameTextField.stringValue = credentials.username
			actionButton.title = NSLocalizedString("button.title.update", comment: "Update")
			signInTextField.stringValue = NSLocalizedString("textfield.text.update-feedbin-credentials", comment: "Update your Feedbin account credentials.")
			noAccountTextField.isHidden = true
			createNewAccountButton.isHidden = true
		} else {
			actionButton.title = NSLocalizedString("button.title.create", comment: "Create")
			signInTextField.stringValue = NSLocalizedString("textfield.text.sign-in-feedbin", comment: "Sign in to your Feedbin account.")
		}
		
		enableAutofill()
		
		usernameTextField.becomeFirstResponder()
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: completion)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func action(_ sender: Any) {

		self.errorMessageLabel.stringValue = ""

		guard !usernameTextField.stringValue.isEmpty && !passwordTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.userNameAndPasswordRequired.localizedDescription

			return
		}

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .feedbin, username: usernameTextField.stringValue) else {
			self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.duplicateAccount.localizedDescription
			return
		}

		actionButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)

		let credentials = Credentials(type: .basic, username: usernameTextField.stringValue, secret: passwordTextField.stringValue)

		Task { @MainActor in
			do {
				let validatedCredentials = try await Account.validateCredentials(type: .feedbin, credentials: credentials)
				if let validatedCredentials {
					if self.account == nil {
						self.account = AccountManager.shared.createAccount(type: .feedbin)
					}
					
					do {
						try self.account?.removeCredentials(type: .basic)
						try self.account?.storeCredentials(validatedCredentials)

						do {
							try await self.account?.refreshAll()
						} catch {
							NSApplication.shared.presentError(error)
						}

						self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
					} catch {
						self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.keychainError.localizedDescription
						self.logger.error("Keychain error while storing credentials: \(error.localizedDescription, privacy: .public)")
					}
				}
				else {
					self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.invalidUsernameOrPassword.localizedDescription
				}
			} catch {
				self.errorMessageLabel.stringValue = LocalizedNetNewsWireError.networkError.localizedDescription
			}

			actionButton.isEnabled = true
			progressIndicator.isHidden = true
			progressIndicator.stopAnimation(self)
		}
	}
	
	@IBAction func createAccountWithProvider(_ sender: Any) {
		NSWorkspace.shared.open(URL(string: "https://feedbin.com/signup")!)
	}
	
	// MARK: Autofill
	func enableAutofill() {
		usernameTextField.contentType = .username
		passwordTextField.contentType = .password
	}
	
}
