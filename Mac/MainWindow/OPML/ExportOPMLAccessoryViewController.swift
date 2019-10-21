//
//  ExportOPMLAccessoryViewController.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2019-10-20.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

class ExportOPMLAccessoryViewController: NSViewController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!

	var selectedAccount: Account? {
		accountPopUpButton.selectedItem?.representedObject as? Account
	}

	init() {
		super.init(nibName: "ExportOPMLAccessoryView", bundle: nil)
	}

	// MARK: - NSViewController

	required init?(coder: NSCoder) {
		preconditionFailure("ExportOPMLAccessoryView.init(coder) not implemented by design.")
	}

	override func viewDidLoad() {
		accountPopUpButton.removeAllItems()

		let menu = NSMenu()
		accountPopUpButton.menu = menu

		for oneAccount in AccountManager.shared.sortedAccounts {

			let oneMenuItem = NSMenuItem()
			oneMenuItem.title = oneAccount.nameForDisplay
			oneMenuItem.representedObject = oneAccount
			menu.addItem(oneMenuItem)

			if oneAccount.accountID == AppDefaults.exportOPMLAccountID {
				accountPopUpButton.select(oneMenuItem)
			}

		}
	}

	@IBAction func accountSelected(_ popUpButton: NSPopUpButton) {
		NotificationCenter.default.post(name: .ExportOPMLSelectedAccountDidChange, object: self)
	}
}

extension Notification.Name {
	static let ExportOPMLSelectedAccountDidChange = Notification.Name(rawValue: "SelectedAccountDidChange")

}
