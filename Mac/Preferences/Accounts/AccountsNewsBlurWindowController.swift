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

class AccountsNewsBlurWindowController: NSWindowController {
	
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
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: completion)
	}

	// MARK: Actions

	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}

	@IBAction func action(_ sender: Any) {
		self.errorMessageLabel.stringValue = ""

		guard !usernameTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username required.", comment: "Credentials Error")
			return
		}
		
		guard account != nil || !AccountManager.shared.duplicateServiceAccount(type: .newsBlur, username: usernameTextField.stringValue) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("There is already a NewsBlur account with that username created.", comment: "Duplicate Error")
			return
		}
		
		actionButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)

		let credentials = Credentials(type: .newsBlurBasic, username: usernameTextField.stringValue, secret: passwordTextField.stringValue)
		Account.validateCredentials(type: .newsBlur, credentials: credentials) { [weak self] result in

			guard let self = self else { return }

			self.actionButton.isEnabled = true
			self.progressIndicator.isHidden = true
			self.progressIndicator.stopAnimation(self)

			switch result {
			case .success(let validatedCredentials):
				guard let validatedCredentials = validatedCredentials else {
					self.errorMessageLabel.stringValue = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
					return
				}

				if self.account == nil {
					self.account = AccountManager.shared.createAccount(type: .newsBlur)
				}

				do {
					try self.account?.removeCredentials(type: .newsBlurBasic)
					try self.account?.removeCredentials(type: .newsBlurSessionId)
					try self.account?.storeCredentials(credentials)
					try self.account?.storeCredentials(validatedCredentials)

					self.account?.refreshAll() { result in
						switch result {
						case .success:
							break
						case .failure(let error):
							NSApplication.shared.presentError(error)
						}
					}
					
					self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
				} catch {
					self.errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
				}

			case .failure:

				self.errorMessageLabel.stringValue = NSLocalizedString("Network error. Try again later.", comment: "Credentials Error")

			}
		}
	}
	
	@IBAction func createAccountWithProvider(_ sender: Any) {
		NSWorkspace.shared.open(URL(string: "https://newsblur.com")!)
	}
	
	// MARK: Autofill
	func enableAutofill() {
		if #available(macOS 11, *) {
			usernameTextField.contentType = .username
			passwordTextField.contentType = .password
		}
	}
	
}
