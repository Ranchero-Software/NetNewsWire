//
//  AccountsAddFeedbinWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/2/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

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
		
		Account.validateCredentials(type: .feedbin, username: usernameTextField.stringValue, password: passwordTextField.stringValue) { [weak self] result in
			
			guard let self = self else { return }
			
			self.createButton.isEnabled = true
			self.progressIndicator.isHidden = true
			self.progressIndicator.stopAnimation(self)
			
			switch result {
			case .success(let authenticated):
				
				if authenticated {
					let account = AccountManager.shared.createAccount(type: .feedbin)
					account.storeCredentials(username: self.usernameTextField.stringValue, password: self.passwordTextField.stringValue)
					
					self.hostWindow?.endSheet(self.window!, returnCode: NSApplication.ModalResponse.OK)
				} else {
					self.errorMessageLabel.stringValue = NSLocalizedString("Unable to verify credentials.", comment: "Credentials Error")
				}

			case .failure:
				
				self.errorMessageLabel.stringValue = NSLocalizedString("Unable to verify credentials due to networking error.", comment: "Credentials Error")
				
			}
			
		}
		
	}
    
}
