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

class AccountsAddFeedbinWindowController: NSWindowController, NSTextFieldDelegate {

	@IBOutlet weak var progressIndicator: NSProgressIndicator!
	@IBOutlet weak var usernameTextField: NSTextField!
	@IBOutlet weak var passwordTextField: NSSecureTextField!
	@IBOutlet weak var errorMessageLabel: NSTextField!
	@IBOutlet weak var createButton: NSButton!
	
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsAddFeedbin"))
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!, completionHandler: handler)
	}
	
	// MARK: NSTextFieldDelegate
	
	func controlTextDidEndEditing(_ obj: Notification) {
		if !usernameTextField.stringValue.isEmpty {
			createButton.isEnabled = true
		} else {
			createButton.isEnabled = false
		}
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func create(_ sender: Any) {
		
		createButton.isEnabled = false
		progressIndicator.isHidden = false
		progressIndicator.startAnimation(self)
		
		let credentials = BasicCredentials(username: usernameTextField.stringValue, password: passwordTextField.stringValue)
		Account.validateCredentials(type: .feedbin, credentials: credentials) { [weak self] result in
			
			guard let self = self else { return }
			
			self.createButton.isEnabled = true
			self.progressIndicator.isHidden = true
			self.progressIndicator.stopAnimation(self)
			
			switch result {
			case .success(let authenticated):
				
				if authenticated {
					let account = AccountManager.shared.createAccount(type: .feedbin)
					do {
						try account.storeCredentials(credentials)
						self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
					} catch {
						self.errorMessageLabel.stringValue = NSLocalizedString("Keychain error while storing credentials.", comment: "Credentials Error")
					}
					
				} else {
					self.errorMessageLabel.stringValue = NSLocalizedString("Invalid email/password combination.", comment: "Credentials Error")
				}

			case .failure:
				
				self.errorMessageLabel.stringValue = NSLocalizedString("Network error.  Try again later.", comment: "Credentials Error")
				
			}
			
		}
		
	}
    
}
