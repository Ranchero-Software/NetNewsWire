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
	@IBOutlet weak var limitationsAndSolutionsRow: NSGridRow!
	@IBOutlet weak var limitationsAndSolutionsTextField: NSTextField!
	@IBOutlet weak var credentialsButton: NSButton!
	@IBOutlet weak var wipeCloudKitArticlesAndReloadButton: NSButton!
	
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
		
		if account?.type == .cloudKit {
			let attrString = NSAttributedString(linkText: CloudKitWebDocumentation.limitationsAndSolutionsText, linkURL: CloudKitWebDocumentation.limitationsAndSolutionsURL)
			limitationsAndSolutionsTextField.attributedStringValue = attrString
		} else {
			limitationsAndSolutionsRow.isHidden = true
			wipeCloudKitArticlesAndReloadButton.isHidden = true
		}
		
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
		
		guard let account = account else { return }
		
		switch account.type {
		case .feedbin:
			let accountsFeedbinWindowController = AccountsFeedbinWindowController()
			accountsFeedbinWindowController.account = account
			accountsFeedbinWindowController.runSheetOnWindow(self.view.window!)
			accountsWindowController = accountsFeedbinWindowController
		case .inoreader, .bazQux, .theOldReader, .freshRSS:
			let accountsReaderAPIWindowController = AccountsReaderAPIWindowController()
			accountsReaderAPIWindowController.accountType = account.type
			accountsReaderAPIWindowController.account = account
			accountsReaderAPIWindowController.runSheetOnWindow(self.view.window!)
			accountsWindowController = accountsReaderAPIWindowController
			break
		case .newsBlur:
			let accountsNewsBlurWindowController = AccountsNewsBlurWindowController()
			accountsNewsBlurWindowController.account = account
			accountsNewsBlurWindowController.runSheetOnWindow(self.view.window!)
			accountsWindowController = accountsNewsBlurWindowController
		default:
			break
		}
		
	}
	
	@IBAction func wipeCloudKitArticlesAndReload(_ sender: Any) {
		let alert = NSAlert()
		alert.alertStyle = .warning
		alert.messageText = NSLocalizedString("Wipe And Reload Articles?", comment: "Wipe And Reload Articles")
		alert.informativeText = NSLocalizedString("Are you sure you want to wipe and reload the iCloud Articles? Only articles in RSS feeds and Starred articles will be reloaded.",
												  comment: "Wipe And Reload Articles")
		
		alert.addButton(withTitle: NSLocalizedString("Wipe And Reload", comment: "Wipe And Reload"))
		alert.addButton(withTitle: NSLocalizedString("Cancel", comment: "Cancel Delete Account"))
			
		alert.beginSheetModal(for: view.window!) { [weak self] result in
			if result == NSApplication.ModalResponse.alertFirstButtonReturn {
				guard let self = self else { return }

				self.wipeCloudKitArticlesAndReloadButton.isEnabled = false
				AccountManager.shared.wipeCloudKitArticlesZoneAndReload(errorHandler: ErrorHandler.present) {
					self.wipeCloudKitArticlesAndReloadButton.isEnabled = true
				}
			}
		}
		
	
	}
	
}
