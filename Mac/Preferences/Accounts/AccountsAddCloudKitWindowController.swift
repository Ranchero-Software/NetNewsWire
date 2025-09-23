//
//  AccountsAddCloudKitWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 3/18/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import Account

final class AccountsAddCloudKitWindowController: NSWindowController {

	private weak var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: "AccountsAddCloudKit")
	}

	// MARK: - API

	func runSheetOnWindow(_ hostWindow: NSWindow, completion: ((NSApplication.ModalResponse) -> Void)? = nil) {
		assert(window != nil)
		guard let window else {
			return
		}

		self.hostWindow = hostWindow
		hostWindow.beginSheet(window, completionHandler: completion)
	}

	// MARK: - Actions

	@IBAction func cancel(_ sender: Any) {
		assert(hostWindow != nil && window != nil)
		guard let hostWindow, let window else {
			return
		}
		
		hostWindow.endSheet(window, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func create(_ sender: Any) {
		assert(!AccountManager.shared.hasiCloudAccount)
		
		guard AddCloudKitAccountUtilities.isiCloudDriveEnabled else {
			presentError(AddCloudKitAccountError.iCloudDriveMissing)
			return
		}

		assert(hostWindow != nil && window != nil)
		guard let hostWindow, let window else {
			return
		}

		let _ = AccountManager.shared.createAccount(type: .cloudKit)
		hostWindow.endSheet(window, returnCode: NSApplication.ModalResponse.OK)
	}
}
