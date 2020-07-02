//
//  NNW3OpenPanelAccessoryViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/14/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class NNW3OpenPanelAccessoryViewController: NSViewController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!

	var selectedAccount: Account? {
		accountPopUpButton.selectedItem?.representedObject as? Account
	}

	init() {
		super.init(nibName: "NNW3OpenPanelAccessoryView", bundle: nil)
	}

	// MARK: - NSViewController
	
	required init?(coder: NSCoder) {
		preconditionFailure("NNW3OpenPanelAccessoryViewController.init(coder) not implemented by design.")
	}

	override func viewDidLoad() {
		accountPopUpButton.removeAllItems()

		let menu = NSMenu()
		accountPopUpButton.menu = menu

		for account in AccountManager.shared.sortedActiveAccounts {
			let menuItem = NSMenuItem()
			menuItem.title = account.nameForDisplay
			menuItem.representedObject = account
			menu.addItem(menuItem)

			if account.accountID == AppDefaults.shared.importOPMLAccountID {
				accountPopUpButton.select(menuItem)
			}
		}
	}
}
