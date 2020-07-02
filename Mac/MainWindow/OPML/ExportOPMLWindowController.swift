//
//  ExportOPMLWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class ExportOPMLWindowController: NSWindowController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("ExportOPMLSheet"))
	}
	
	override func windowDidLoad() {
		accountPopUpButton.removeAllItems()

		let menu = NSMenu()
		accountPopUpButton.menu = menu
		
		for oneAccount in AccountManager.shared.sortedAccounts {
			
			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)
			
			if oneAccount.accountID == AppDefaults.shared.exportOPMLAccountID {
				accountPopUpButton.select(oneMenuItem)
			}

		}
	}

	// MARK: API
	
	func runSheetOnWindow(_ hostWindow: NSWindow) {
		
		self.hostWindow = hostWindow
		
		if AccountManager.shared.accounts.count == 1 {
			let account = AccountManager.shared.accounts.first!
			exportOPML(account: account)
		} else {
			hostWindow.beginSheet(window!)
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func exportOPML(_ sender: Any) {

		guard let menuItem = accountPopUpButton.selectedItem else {
			return
		}

		let account = menuItem.representedObject as! Account
		AppDefaults.shared.exportOPMLAccountID = account.accountID
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
		exportOPML(account: account)
		
	}
	
	func exportOPML(account: Account) {
		
		let panel = NSSavePanel()
		panel.allowedFileTypes = ["opml"]
		panel.allowsOtherFileTypes = false
		panel.prompt = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.title = NSLocalizedString("Export OPML", comment: "Export OPML")
		panel.nameFieldLabel = NSLocalizedString("Export to:", comment: "Export OPML")
		panel.message = NSLocalizedString("Choose a location for the exported OPML file.", comment: "Export OPML")
		panel.isExtensionHidden = false
		
		let accountName = account.nameForDisplay.replacingOccurrences(of: " ", with: "").trimmingCharacters(in: .whitespaces)
		panel.nameFieldStringValue = "Subscriptions-\(accountName).opml"
		
		panel.beginSheetModal(for: hostWindow!) { result in
			if result == NSApplication.ModalResponse.OK, let url = panel.url {
				DispatchQueue.main.async {
					let filename = url.lastPathComponent
					let opmlString = OPMLExporter.OPMLString(with: account, title: filename)
					do {
						try opmlString.write(to: url, atomically: true, encoding: String.Encoding.utf8)
					}
					catch let error as NSError {
						NSApplication.shared.presentError(error)
					}
				}
			}
		}
		
	}
	
}
