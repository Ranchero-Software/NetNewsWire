//
//  AddTwitterFeedWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/21/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account

class AddTwitterFeedWindowController : NSWindowController, AddFeedWindowController {
    

	@IBOutlet weak var accountPopupButton: NSPopUpButton!
	@IBOutlet weak var typePopupButton: NSPopUpButton!
	@IBOutlet weak var typeDescriptionLabel: NSTextField!
	@IBOutlet weak var screenSearchTextField: NSTextField!
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

	convenience init(folderTreeController: TreeController, delegate: AddFeedWindowControllerDelegate?) {
		self.init(windowNibName: NSNib.Name("AddTwitterFeedSheet"))
		self.folderTreeController = folderTreeController
		self.delegate = delegate
	}
	
    func runSheetOnWindow(_ hostWindow: NSWindow) {
		hostWindow.beginSheet(window!) { (returnCode: NSApplication.ModalResponse) -> Void in
		}
    }

	override func windowDidLoad() {

		typeDescriptionLabel.stringValue = "Tweets from everyone you follow"
		screenSearchTextField.isHidden = true
		
		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController.rootNode)
		
		if let container = AddWebFeedDefaultContainer.defaultContainer {
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

		// TODO: Build the URL...
		let url = URL(string: "https://twitter.com")!
		
		let container = selectedContainer()!
		AddWebFeedDefaultContainer.saveDefaultContainer(container)
		delegate?.addFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container)
    }
	
	// MARK: NSTextFieldDelegate

	@objc func controlTextDidEndEditing(_ obj: Notification) {
		updateUI()
	}

	@objc func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
	
}

private extension AddTwitterFeedWindowController {
	
	private func updateUI() {
//		addButton.isEnabled = urlTextField.stringValue.mayBeURL
	}

	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
