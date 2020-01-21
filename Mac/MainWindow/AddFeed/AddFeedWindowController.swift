//
//  AddFeedWindowController.swift
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

protocol AddFeedWindowControllerDelegate: class {

	// userEnteredURL will have already been validated and normalized.
	func addFeedWindowController(_: AddFeedWindowController, userEnteredURL: URL, userEnteredTitle: String?, container: Container)

	func addFeedWindowControllerUserDidCancel(_: AddFeedWindowController)
}

class AddFeedWindowController : NSWindowController {
    
    @IBOutlet var urlTextField: NSTextField!
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var folderPopupButton: NSPopUpButton!

	private var urlString: String?
	private var initialName: String?
	private weak var initialAccount: Account?
	private var initialFolder: Folder?
	private weak var delegate: AddFeedWindowControllerDelegate?
	private var folderTreeController: TreeController!

	private var userEnteredTitle: String? {
		var s = nameTextField.stringValue
		s = s.collapsingWhitespace
		if s.isEmpty {
			return nil
		}
		return s
	}
	
    var hostWindow: NSWindow!

	convenience init(urlString: String?, name: String?, account: Account?, folder: Folder?, folderTreeController: TreeController, delegate: AddFeedWindowControllerDelegate?) {
		self.init(windowNibName: NSNib.Name("AddFeedSheet"))
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

		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController.rootNode)
		
		if let account = initialAccount {
			FolderTreeMenu.select(account: account, folder: initialFolder, in: folderPopupButton)
		} else if let container = AddWebFeedDefaultContainer.defaultContainer {
			if let folder = container as? Folder, let account = folder.account {
				FolderTreeMenu.select(account: account, folder: folder, in: folderPopupButton)
			} else {
				if let account = container as? Account {
					FolderTreeMenu.select(account: account, folder: nil, in: folderPopupButton)
				}
			}
		}
		
		updateUI()
	}

    // MARK: Actions
    
    @IBAction func cancel(_ sender: Any?) {
		cancelSheet()
    }
    
    @IBAction func addFeed(_ sender: Any?) {
		let urlString = urlTextField.stringValue
		let normalizedURLString = urlString.normalizedURL

		if normalizedURLString.isEmpty {
			cancelSheet()
			return;
		}
		guard let url = URL(string: normalizedURLString) else {
			cancelSheet()
			return
		}
		
		let container = selectedContainer()!
		AddWebFeedDefaultContainer.saveDefaultContainer(container)

		delegate?.addFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container)
		
    }

	@IBAction func localShowFeedList(_ sender: Any?) {
		NSApplication.shared.sendAction(NSSelectorFromString("showFeedList:"), to: nil, from: sender)
		hostWindow.endSheet(window!, returnCode: NSApplication.ModalResponse.continue)
	}
	
	// MARK: NSTextFieldDelegate

	@objc func controlTextDidEndEditing(_ obj: Notification) {
		updateUI()
	}

	@objc func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
}

private extension AddFeedWindowController {
	
	private func updateUI() {
		addButton.isEnabled = urlTextField.stringValue.mayBeURL
	}

	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
