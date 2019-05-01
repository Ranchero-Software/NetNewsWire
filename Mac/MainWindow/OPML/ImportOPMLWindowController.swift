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
		for oneAccount in AccountManager.shared.sortedAccounts {
			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)
		}
		accountPopUpButton.menu = menu
		
	}
	
	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		self.hostWindow = hostWindow
		hostWindow.beginSheet(window!)
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

		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
		
		let panel = NSOpenPanel()
		panel.canDownloadUbiquitousContents = true
		panel.canResolveUbiquitousConflicts = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.resolvesAliases = true
		panel.allowedFileTypes = ["opml", "xml"]
		panel.allowsOtherFileTypes = false
		
		panel.beginSheetModal(for: hostWindow!) { result in
			if result == NSApplication.ModalResponse.OK, let url = panel.url {
				DispatchQueue.main.async {
					do {
						try OPMLImporter.parseAndImport(fileURL: url, account: account)
					}
					catch let error as NSError {
						NSApplication.shared.presentError(error)
					}
				}
			}
		}
		
	}

}
