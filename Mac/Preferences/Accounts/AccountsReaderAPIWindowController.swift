//
//  AccountsAddFeedbinWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSWeb

class AccountsReaderAPIWindowController: NSWindowController {

	@IBOutlet weak var titleImageView: NSImageView!
	@IBOutlet weak var titleLabel: NSTextField!
	
	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var usernameTextField: NSTextField!
	@IBOutlet weak var apiURLTextField: NSTextField!
	@IBOutlet weak var passwordTextField: NSSecureTextField!
	@IBOutlet weak var errorMessageLabel: NSTextField!
	@IBOutlet weak var actionButton: NSButton!
	
	var account: Account?
	var accountType: AccountType?
	
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsReaderAPI"))
	}
	
	override func windowDidLoad() {
		if let accountType = accountType {
			switch accountType {
			case .freshRSS:
				titleImageView.image = AppAssets.accountFreshRSS
				titleLabel.stringValue = NSLocalizedString("FreshRSS", comment: "FreshRSS")
			default:
				break
			}
		}
		
		if let account = account, let credentials = try? account.retrieveCredentials() {
			if case .basic(let username, _) = credentials {
				usernameTextField.stringValue = username
			}
			actionButton.title = NSLocalizedString("Update", comment: "Update")
		} else {
			actionButton.title = NSLocalizedString("Create", comment: "Create")
		}
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: handler)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func action(_ sender: Any) {
		
		self.errorMessageLabel.stringValue = ""
		
		guard !usernameTextField.stringValue.isEmpty && !passwordTextField.stringValue.isEmpty && !apiURLTextField.stringValue.isEmpty else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Username, password & API URL are required.", comment: "Credentials Error")
			return
		}
		
		actionButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)
		
		guard let apiURL = URL(string: apiURLTextField.stringValue) else {
			self.errorMessageLabel.stringValue = NSLocalizedString("Invalid API URL.", comment: "Credentials Error")
			return
		}
		
		let credentials = Credentials.readerAPIBasicLogin(username: usernameTextField.stringValue, password: passwordTextField.stringValue)
		Account.validateCredentials(type: accountType!, credentials: credentials, endpoint: apiURL) { [weak self] result in
			
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
					self.account = AccountManager.shared.createAccount(type: self.accountType!)
					newAccount = true
				}
				
				do {
					self.account?.endpointURL = apiURL

					try self.account?.removeCredentials()
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
				self.errorMessageLabel.stringValue = NSLocalizedString("Network error.  Try again later.", comment: "Credentials Error")
			}
			
		}
		
	}
    
}
