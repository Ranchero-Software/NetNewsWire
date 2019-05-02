//
//  AccountsDetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 3/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

final class AccountsDetailViewController: NSViewController, NSTextFieldDelegate {

	@IBOutlet weak var typeLabel: NSTextField!
	@IBOutlet weak var nameTextField: NSTextField!
	@IBOutlet weak var activeButton: NSButtonCell!
	
	private weak var account: Account?

	init(account: Account) {
		super.init(nibName: "AccountsDetail", bundle: nil)
		self.account = account
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		nameTextField.delegate = self
		typeLabel.stringValue = account?.defaultName ?? ""
		nameTextField.stringValue = account?.name ?? ""
		activeButton.state = account?.isActive ?? false ? .on : .off
	}
	
	func controlTextDidEndEditing(_ obj: Notification) {
		if !nameTextField.stringValue.isEmpty {
			account?.name = nameTextField.stringValue
		} else {
			account?.name = nil
		}
	}
	
	@IBAction func active(_ sender: NSButtonCell) {
		account?.isActive = sender.state == .on ? true : false
	}
	
}
