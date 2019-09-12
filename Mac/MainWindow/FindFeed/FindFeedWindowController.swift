//
//  FindFeedWindowController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account

protocol FindFeedWindowControllerDelegate: class {

	// userEnteredURL will have already been validated and normalized.
	func findFeedWindowController(_: FindFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)

	func findFeedWindowControllerUserDidCancel(_: FindFeedWindowController)
}

class FindFeedWindowController : NSWindowController {
    
    @IBOutlet var urlTextField: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!

	private var urlString: String?
	private var initialName: String?
	private weak var initialAccount: Account?
	private var initialFolder: Folder?
	private weak var delegate: FindFeedWindowControllerDelegate?
	private var folderTreeController: TreeController!

	private var userEnteredTitle: String? {
		var s = nameTextField.stringValue
		s = s.rs_stringWithCollapsedWhitespace()
		if s.isEmpty {
			return nil
		}
		return s
	}
	
	convenience init(urlString: String?, name: String?, account: Account?, folder: Folder?, folderTreeController: TreeController, delegate: FindFeedWindowControllerDelegate?) {
		self.init(windowNibName: NSNib.Name("FindFeedSheet"))
		self.urlString = urlString
		self.initialName = name
		self.initialAccount = account
		self.initialFolder = folder
		self.delegate = delegate
		self.folderTreeController = folderTreeController
	}
	
    func runSheetOnWindow(_ hostWindow: NSWindow) {
		
		hostWindow.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
    }

	override func windowDidLoad() {
		if let urlString = urlString {
			urlTextField.stringValue = urlString
		}
		if let initialName = initialName, !initialName.isEmpty {
			nameTextField.stringValue = initialName
		}

		updateUI()
	}

    // MARK: Actions
    
    @IBAction func cancel(_ sender: Any?) {
		cancelSheet()
    }
    
    @IBAction func addFeed(_ sender: Any?) {
		let urlString = urlTextField.stringValue
		let normalizedURLString = (urlString as NSString).rs_normalizedURL()

		if normalizedURLString.isEmpty {
			cancelSheet()
			return;
		}
		guard let url = URL(string: normalizedURLString) else {
			cancelSheet()
			return
		}
		
		let container = selectedContainer()!
		if let selectedAccount = container as? Account {
			AppDefaults.addFeedAccountID = selectedAccount.accountID
		} else if let selectedFolder = container as? Folder, let selectedAccount = selectedFolder.account {
			AppDefaults.addFeedAccountID = selectedAccount.accountID
		}

		delegate?.findFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container)
		
    }
	
	// MARK: NSTextFieldDelegate

	@objc func controlTextDidEndEditing(_ obj: Notification) {
		updateUI()
	}

	@objc func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
}

private extension FindFeedWindowController {
	
	private func updateUI() {
		addButton.isEnabled = urlTextField.stringValue.rs_stringMayBeURL()
	}

	func cancelSheet() {
		delegate?.findFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return nil
	}
}
