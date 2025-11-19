//
//  AccountsNewsBlurWindowController.swift
//  NetNewsWire
//
//  Created by Anh Quang Do on 2020-03-22.
//  Copyright (c) 2020 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSWeb
import Secrets

final class AccountsNewsBlurWindowController: NSWindowController {

	@IBOutlet var signInTextField: NSTextField!
	@IBOutlet var noAccountTextField: NSTextField!
	@IBOutlet var createNewAccountButton: NSButton!
	@IBOutlet var progressIndicator: NSProgressIndicator!
	@IBOutlet var usernameTextField: NSTextField!
	@IBOutlet var passwordTextField: NSSecureTextField!
	@IBOutlet var errorMessageLabel: NSTextField!
	@IBOutlet var actionButton: NSButton!

	var account: Account?

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsNewsBlur"))
	}

	override func windowDidLoad() {
		if let account = account, let credentials = try? account.retrieveCredentials(type: .newsBlurBasic) {
			usernameTextField.stringValue = credentials.username
			actionButton.title = NSLocalizedString("Update", comment: "Update")
			signInTextField.stringValue = NSLocalizedString("Update your NewsBlur account credentials.", comment: "SignIn")
			noAccountTextField.isHidden = true
			createNewAccountButton.isHidden = true
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
			signInTextField.stringValue = NSLocalizedString("Sign in to your NewsBlur account.", comment: "SignIn")
		}
		enableAutofill()
		usernameTextField.becomeFirstResponder()
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

		guard !usernameTextField.stringValue.isEmpty else {
			errorMessageLabel.stringValue = NSLocalizedString("Username required.", comment: "Credentials Error")
			return
		}

		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .newsBlur, username: usernameTextField.stringValue) else {
			errorMessageLabel.stringValue = NSLocalizedString("There is already a NewsBlur account with that username created.", comment: "Duplicate Error")
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

			let credentials = Credentials(type: .newsBlurBasic, username: usernameTextField.stringValue, secret: passwordTextField.stringValue)
			do {
				let validatedCredentials = try await Account.validateCredentials(type: .newsBlur, credentials: credentials)
				stopAnimation()

				guard let validatedCredentials else {
					errorMessageLabel.stringValue = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
					return
				}

				if account == nil {
					account = AccountManager.shared.createAccount(type: .newsBlur)
				}

				do {
					try account?.removeCredentials(type: .newsBlurBasic)
					try account?.removeCredentials(type: .newsBlurSessionID)
					try account?.storeCredentials(credentials)
					try account?.storeCredentials(validatedCredentials)

					do {
						try await account?.refreshAll()
					} catch {
						NSApplication.shared.presentError(error)
					}

					hostWindow?.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
				} catch {
					self.errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}
			} catch {
				stopAnimation()
				errorMessageLabel.stringValue = NSLocalizedString("Network error. Try again later.", comment: "Credentials Error")
			}
		}
	}

	@IBAction func createAccountWithProvider(_ sender: Any) {
		NSWorkspace.shared.open(URL(string: "https://newsblur.com")!)
	}

	// MARK: Autofill
	func enableAutofill() {
		usernameTextField.contentType = .username
		passwordTextField.contentType = .password
	}

}
