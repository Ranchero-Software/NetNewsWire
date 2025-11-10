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
	@IBOutlet weak var credentialsButton: NSButton!

	private var accountsWindowController: NSWindowController?
	private var account: Account?

	init(account: Account) {
		super.init(nibName: "AccountsDetail", bundle: nil)
		self.account = account
	}

	public required init?(coder: NSCoder) {
		super.init(coder: coder)
	}

	private var hidesCredentialsButton: Bool {
		guard let account = account else {
			return true
		}
		switch account.type {
		case .onMyMac, .cloudKit, .feedly:
			return true
		default:
			return false
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		nameTextField.delegate = self
		typeLabel.stringValue = account?.defaultName ?? ""
		nameTextField.stringValue = account?.name ?? ""
		activeButton.state = account?.isActive ?? false ? .on : .off
		credentialsButton.isHidden = hidesCredentialsButton
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

	@IBAction func credentials(_ sender: Any) {
		guard let account else {
			return
		}
		guard let window = view.window else {
			return
		}

		switch account.type {
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsWindowController = accountsFeedbinWindowController
			accountsFeedbinWindowController.account = account
			accountsFeedbinWindowController.runSheetOnWindow(window)

		case .inoreader, .bazQux, .theOldReader, .freshRSS:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsWindowController = accountsReaderAPIWindowController
			accountsReaderAPIWindowController.accountType = account.type
			accountsReaderAPIWindowController.account = account
			accountsReaderAPIWindowController.runSheetOnWindow(window)

		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsWindowController = accountsNewsBlurWindowController
			accountsNewsBlurWindowController.account = account
			accountsNewsBlurWindowController.runSheetOnWindow(window)

		default:
			break
		}
	}
}
