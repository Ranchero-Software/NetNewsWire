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

class AddFolderWindowController : NSWindowController {
    
    @IBOutlet var folderNameTextField: NSTextField!
    @IBOutlet var accountPopupButton: NSPopUpButton!
	@IBOutlet var addFolderButton: NSButton!
	private var hostWindow: NSWindow?

	convenience init() {
		self.init(windowNibName: NSNib.Name("AddFolderSheet"))
	}

    // MARK: - API
    
    func runSheetOnWindow(_ w: NSWindow) {
		hostWindow = w
		hostWindow!.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
			
			if returnCode == NSApplication.ModalResponse.OK {
				self.addFolderIfNeeded()
			}
		}
    }

	// MARK: - NSViewController
	
	override func windowDidLoad() {
		let preferredAccountID = AppDefaults.shared.addFolderAccountID
		accountPopupButton.removeAllItems()
		
		let menu = NSMenu()
		accountPopupButton.menu = menu
		
		let accounts = AccountManager.shared
			.sortedActiveAccounts
			.filter { !$0.behaviors.contains(.disallowFolderManagement) }
		
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
		hostWindow!.endSheet(window!, returnCode: .cancel)
    }
    
    @IBAction func addFolder(_ sender: Any?) {
		hostWindow!.endSheet(window!, returnCode: .OK)
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

		account.addFolder(folderName) { result in
			switch result {
			case .success:
				break
			case .failure(let error):
				NSApplication.shared.presentError(error)
			}
		}
	}
}
