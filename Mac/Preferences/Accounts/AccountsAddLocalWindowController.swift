//
//  AccountsAddLocalWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class AccountsAddLocalWindowController: NSWindowController {

	@IBOutlet weak var nameTextField: NSTextField!

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsAddLocal"))
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!)
	}

	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func create(_ sender: Any) {
		let account = AccountManager.shared.createAccount(type: .onMyMac)
		if !nameTextField.stringValue.isEmpty {
			account.name = nameTextField.stringValue
		}
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}
	
}
