//
//  ImportNNW3WindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class ImportNNW3WindowController: NSWindowController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!
	private weak var hostWindow: NSWindow?
	
	convenience init() {
		self.init(windowNibName: NSNib.Name("ImportNNW3Sheet"))
	}
	
	override func windowDidLoad() {
		accountPopUpButton.removeAllItems()
		
		let menu = NSMenu()
		accountPopUpButton.menu = menu

		for oneAccount in AccountManager.shared.sortedActiveAccounts {
			
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
			importNNW3(account: account)
		} else {
			hostWindow.beginSheet(window!)
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func cancel(_ sender: Any) {
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.cancel)
	}
	
	@IBAction func importNNW3(_ sender: Any) {

		guard let menuItem = accountPopUpButton.selectedItem else {
			return
		}
		
		let account = menuItem.representedObject as! Account
		AppDefaults.importOPMLAccountID = account.accountID
		hostWindow!.endSheet(window!, returnCode: NSApplication.ModalResponse.OK)
		importNNW3(account: account)
		
	}
	
	func importNNW3(account: Account) {
		
		let panel = NSOpenPanel()
		panel.canDownloadUbiquitousContents = true
		panel.canResolveUbiquitousConflicts = true
		panel.canChooseFiles = true
		panel.allowsMultipleSelection = false
		panel.canChooseDirectories = false
		panel.resolvesAliases = true
		panel.directoryURL = URL(fileURLWithPath: NNW3PlistConverter.defaultFilePath)
		panel.allowedFileTypes = ["plist"]
		panel.allowsOtherFileTypes = false
		
		panel.beginSheetModal(for: hostWindow!) { modalResult in
			if modalResult == NSApplication.ModalResponse.OK, let url = panel.url {
				
				guard let opmlURL = NNW3PlistConverter.convertToOPML(url: url) else {
					return
				}
				
				account.importOPML(opmlURL) { result in
					try? FileManager.default.removeItem(at: opmlURL)
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
