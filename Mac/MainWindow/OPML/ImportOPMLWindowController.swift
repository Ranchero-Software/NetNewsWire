//
//  ImportOPMLWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class ImportOPMLWindowController: NSWindowController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("ImportOPMLSheet"))
	}
	
	override func windowDidLoad() {
		accountPopUpButton.removeAllItems()
		
		let menu = NSMenu()
		accountPopUpButton.menu = menu

		for oneAccount in AccountManager.shared.sortedActiveAccounts {
			
			if !oneAccount.isOPMLImportSupported {
				continue
			}
			
			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)
			
			if oneAccount.accountID == AppDefaults.importOPMLAccountID {
				accountPopUpButton.select(oneMenuItem)
			}
			
		}
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		
		self.hostWindow = hostWindow
		
		if AccountManager.shared.activeAccounts.count == 1 {
			let account = AccountManager.shared.activeAccounts.first!
			importOPML(account: account)
		} else {
			hostWindow.beginSheet(window!)
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func importOPML(_ sender: Any) {

		guard let menuItem = accountPopUpButton.selectedItem else {
			return
		}
		
		let account = menuItem.representedObject as! Account
		AppDefaults.importOPMLAccountID = account.accountID
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
		importOPML(account: account)
		
	}
	
	func importOPML(account: Account) {
		
		let panel = NSOpenPanel()
		panel.canDownloadUbiquitousContents = true
		panel.canResolveUbiquitousConflicts = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.resolvesAliases = true
		panel.allowedFileTypes = ["opml", "xml"]
		panel.allowsOtherFileTypes = false
		
		panel.beginSheetModal(for: hostWindow!) { modalResult in
			if modalResult == NSApplication.ModalResponse.OK, let url = panel.url {
				account.importOPML(url) { result in
					switch result {
					case .success:
						break
					case .failure(let error):
						NSApplication.shared.presentError(error)
					}
				}
			}
		}
		
	}

}
