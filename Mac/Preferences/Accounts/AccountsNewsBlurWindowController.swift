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

class AccountsNewsBlurWindowController: NSWindowController {
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
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
		}
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
				var newAccount = false
				if self.account == nil {
					self.account = AccountManager.shared.createAccount(type: .newsBlur)
					newAccount = true
				}

				do {
					try self.account?.removeCredentials(type: .newsBlurBasic)
					try self.account?.removeCredentials(type: .newsBlurSessionId)
					try self.account?.storeCredentials(credentials)
					try self.account?.storeCredentials(validatedCredentials)
					if newAccount {
						self.account?.refreshAll() { result in
							switch result {
							case .success:
								break
							case .failure(let error):
								NSApplication.shared.presentError(error)
							}
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
}
