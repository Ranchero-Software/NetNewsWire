//
//  AddFolderWindowController.swift
//  Evergreen
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
    var hostWindow: NSWindow?

	convenience init() {

		self.init(windowNibName: NSNib.Name(rawValue: "AddFolderSheet"))
	}

    // MARK: API
    
    func runSheetOnWindow(_ w: NSWindow) {

		hostWindow = w
		hostWindow!.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
			
			if returnCode == NSApplication.ModalResponse.OK {
				self.addFolderIfNeeded()
			}
		}
    }

	// MARK: NSViewController
	
	override func windowDidLoad() {
		
		accountPopupButton.removeAllItems()
		let menu = NSMenu()
		for oneAccount in AccountManager.shared.sortedAccounts {
			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)
		}
		accountPopupButton.menu = menu
	}
	
	// MARK: Private
	
	private func addFolderIfNeeded() {
		
		guard let menuItem = accountPopupButton.selectedItem else {
			return
		}
		let account = menuItem.representedObject as! Account
		
		let folderName = self.folderNameTextField.stringValue
		if folderName.isEmpty {
			return
		}
		
		account.ensureFolder(with: folderName)
	}
	
	// MARK: Actions
	
    @IBAction func cancel(_ sender: Any?) {
        
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
    }
    
    @IBAction func addFolder(_ sender: Any?) {
        
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
    }
    
}
