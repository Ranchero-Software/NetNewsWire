//
//  ExportOPMLAccessoryViewController.swift
//  NetNewsWire
//
//  Created by Nate Weaver on 2019-10-20.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

protocol ExportOPMLAccessoryViewControllerDelegate: class {
	func selectedAccountDidChange(_ accessoryViewController: ExportOPMLAccessoryViewController)
}

class ExportOPMLAccessoryViewController: NSViewController {

	@IBOutlet weak var accountPopUpButton: NSPopUpButton!
	weak var delegate: ExportOPMLAccessoryViewControllerDelegate?

	var selectedAccount: Account? {
		accountPopUpButton.selectedItem?.representedObject as? Account
	}

	init(delegate: ExportOPMLAccessoryViewControllerDelegate) {
		super.init(nibName: "ExportOPMLAccessoryView", bundle: nil)
		self.delegate = delegate
	}

	init() {
		preconditionFailure("init() without delegate not implemented by design.")
	}

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
		delegate!.selectedAccountDidChange(self)
	}
}

