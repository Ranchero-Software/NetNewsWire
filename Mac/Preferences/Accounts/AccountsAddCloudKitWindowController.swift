//
//  AccountsAddCloudKitWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

class AccountsAddCloudKitWindowController: NSWindowController {

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AccountsAddCloudKit"))
	}
	
	override func windowDidLoad() {
		super.windowDidLoad()
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
	
	@IBAction func create(_ sender: Any) {
		let account = AccountManager.shared.createAccount(type: .cloudKit)
		account.refreshAll(completion: { _ in })
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}
	
}
