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
		accountPopupButton.removeAllItems()

		let menu = NSMenu()
		accountPopupButton.menu = menu

		let preferredAccountID = AppDefaults.shared.addFolderAccountID
		for account in allowedAccountsForFolderCreation() {
			let menuItem = addMenuItem(to: menu, for: account)
			if account.accountID == preferredAccountID {
				accountPopupButton.select(menuItem)
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

	func allowedAccountsForFolderCreation() -> [Account] {
		AccountManager.shared.sortedActiveAccounts.filter { account in
			!account.behaviors.contains(.disallowFolderManagement)
		}
	}

	@discardableResult
	func addMenuItem(to menu: NSMenu, for account: Account) -> NSMenuItem {
		let menuItem = NSMenuItem()
		menuItem.title = account.nameForDisplay
		menuItem.representedObject = account
		menu.addItem(menuItem)
		return menuItem
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
