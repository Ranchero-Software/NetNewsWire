//
//  AddFolderWindowController.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Cocoa
import DataModel

//func addFolderWindowController() -> AddFolderWindowController {
//	
//	return AddFolderWindowController(windowNibName: "AddFolderSheet")
//}

class AddFolderWindowController : NSWindowController {
    
    @IBOutlet var folderNameTextField: NSTextField!
    @IBOutlet var accountPopupButton: NSPopUpButton!
    var hostWindow: NSWindow?

	convenience init() {

		self.init(windowNibName: "AddFolderSheet")
	}

    // MARK: API
    
    func runSheetOnWindow(_ w: NSWindow) {

		hostWindow = w
        hostWindow!.beginSheet(window!) { (returnCode: NSModalResponse) -> Void in
			
			if returnCode == NSModalResponseOK {
				self.addFolderIfNeeded()
			}
		}
    }

	// MARK: NSViewController
	
	override func windowDidLoad() {
		
		accountPopupButton.removeAllItems()
		let menu = NSMenu()
		for oneAccount in AccountManager.sharedInstance.sortedAccounts {
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
		
		let _ = account.ensureFolderWithName(folderName)
	}
	
	// MARK: Actions
	
    @IBAction func cancel(_ sender: AnyObject) {
        
        hostWindow!.endSheet(window!, returnCode: NSModalResponseCancel)
    }
    
    @IBAction func addFolder(_ sender: AnyObject) {
        
        hostWindow!.endSheet(window!, returnCode: NSModalResponseOK)
    }
    
}
