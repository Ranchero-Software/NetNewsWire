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

	@IBOutlet private weak var nameTextField: NSTextField!
	@IBOutlet private weak var localAccountNameTextField: NSTextField!
	
	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsAddLocal"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
		
		localAccountNameTextField.stringValue = NSLocalizedString("Create a local account on your Mac.", comment: "Account Local")
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
