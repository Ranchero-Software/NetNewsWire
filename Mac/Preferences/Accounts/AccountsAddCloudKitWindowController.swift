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
	private var isCheckingiCloud = false

	convenience init() {
		self.init(windowNibName: "AccountsAddCloudKit")
	}

	// MARK: - API

	func runSheetOnWindow(_ hostWindow: NSWindow) async -> NSApplication.ModalResponse? {
		assert(window != nil)
		guard let window else {
			return nil
		}

		self.hostWindow = hostWindow
		return await hostWindow.beginSheet(window)
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
		guard !isCheckingiCloud else {
			return
		}
		assert(!AccountManager.shared.hasiCloudAccount)

		isCheckingiCloud = true
		Task {
			defer {
				isCheckingiCloud = false
			}

			guard await AccountManager.shared.isiCloudAvailable() else {
				presentError(AddCloudKitAccountError.iCloudUnavailable)
				return
			}

			assert(hostWindow != nil && window != nil)
			guard let hostWindow, let window else {
				return
			}

			_ = AccountManager.shared.createAccount(type: .cloudKit)
			hostWindow.endSheet(window, returnCode: NSApplication.ModalResponse.OK)
		}
	}
}
