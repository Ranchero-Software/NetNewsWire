//
//  AddFolderWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import Articles
import Account

final class AddFolderWindowController: NSWindowController {

    @IBOutlet var folderNameTextField: NSTextField!
    @IBOutlet var accountPopupButton: NSPopUpButton!
	@IBOutlet var addFolderButton: NSButton!
	private var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AddFolderSheet"))
	}

    // MARK: - API

    func runSheetOnWindow(_ hostWindow: NSWindow) {
		guard let window else {
			return
		}
		self.hostWindow = hostWindow

		Task { @MainActor in
			let response = await hostWindow.beginSheet(window)
			if response == .OK {
				addFolderIfNeeded()
			}
		}
    }

	// MARK: - NSViewController

	override func windowDidLoad() {
		super.windowDidLoad()

		let preferredAccountID = AppDefaults.shared.addFolderAccountID
		accountPopupButton.removeAllItems()

		let menu = NSMenu()
		accountPopupButton.menu = menu

		let sortedAccounts: [Account] = AccountManager.shared.sortedActiveAccounts
		let accounts = folderManageableAccounts(from: sortedAccounts)

		for oneAccount in accounts {

			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)

			if oneAccount.accountID == preferredAccountID {
				accountPopupButton.select(oneMenuItem)
			}
		}
	}

	// MARK: - Actions

    @IBAction func cancel(_ sender: Any?) {
		guard let hostWindow, let window else {
			return
		}
		hostWindow.endSheet(window, returnCode: .cancel)
		self.hostWindow = nil
    }

    @IBAction func addFolder(_ sender: Any?) {
		guard let hostWindow, let window else {
			return
		}
		hostWindow.endSheet(window, returnCode: .OK)
		self.hostWindow = nil
    }
}

// MARK: - Text Field Delegate

extension AddFolderWindowController: NSTextFieldDelegate {

	func controlTextDidChange(_ obj: Notification) {
		guard let folderName = (obj.object as? NSTextField)?.stringValue else {
			addFolderButton.isEnabled = false
			return
		}
		addFolderButton.isEnabled = !folderName.isEmpty
	}
}

// MARK: - Private

private extension AddFolderWindowController {

	func folderManageableAccounts(from accounts: [Account]) -> [Account] {
		var results = [Account]()
		results.reserveCapacity(accounts.count)

		for account in accounts {
			if !account.behaviors.contains(.disallowFolderManagement) {
				results.append(account)
			}
		}

		return results
	}

	private func addFolderIfNeeded() {
		guard let menuItem = accountPopupButton.selectedItem else {
			return
		}

		let account = menuItem.representedObject as! Account
		AppDefaults.shared.addFolderAccountID = account.accountID

		let folderName = self.folderNameTextField.stringValue
		if folderName.isEmpty {
			return
		}

		Task { @MainActor in
			do {
				try await account.addFolder(folderName)
			} catch {
				NSApplication.shared.presentError(error)
			}
		}
	}
}
