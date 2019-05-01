//
//  AccountsDeleteWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class AccountsDeleteWindowController: NSWindowController {

	@IBOutlet weak var deleteLabel: NSTextField!
	private weak var hostWindow: NSWindow?
	
	var account: Account?
	
	convenience init(account: Account) {
		self.init(windowNibName: NSNib.Name("AccountsDelete"))
		self.account = account
	}
	
	override func windowDidLoad() {
		let deletePrompt = NSLocalizedString("Delete", comment: "Delete")
		deleteLabel.stringValue = "\(deletePrompt) \"\(account?.nameForDisplay ?? "")\"?"
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

		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}
    
}
