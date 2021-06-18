//
//  AccountsAddCloudKitWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

enum AccountsAddCloudKitWindowControllerError: LocalizedError {
	case iCloudDriveMissing
	
	var errorDescription: String? {
		return NSLocalizedString("Unable to add iCloud Account. Please make sure you have iCloud and iCloud enabled in System Preferences.", comment: "Unable to add iCloud Account.")
	}
}

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
		guard FileManager.default.ubiquityIdentityToken != nil else {
			NSApplication.shared.presentError(AccountsAddCloudKitWindowControllerError.iCloudDriveMissing)
			return
		}
		
		let _ = AccountManager.shared.createAccount(type: .cloudKit)
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
	}
	
}
