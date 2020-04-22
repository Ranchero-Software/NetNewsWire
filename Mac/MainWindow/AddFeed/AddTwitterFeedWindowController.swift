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
    

	@IBOutlet weak var typePopupButton: NSPopUpButton!
	@IBOutlet weak var typeDescriptionLabel: NSTextField!

	@IBOutlet weak var accountLabel: NSTextField!
	@IBOutlet weak var accountPopupButton: NSPopUpButton!
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
    
	@IBAction func selectedType(_ sender: Any) {
		screenSearchTextField.stringValue = ""
		updateUI()
	}

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
	
}

extension AddTwitterFeedWindowController: NSTextFieldDelegate {

	func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
	
}

private extension AddTwitterFeedWindowController {
	
	private func updateUI() {
		
		switch typePopupButton.selectedItem?.tag ?? 0 {
		case 0:
			
			accountLabel.isHidden = false
			accountPopupButton.isHidden = false
			typeDescriptionLabel.stringValue = NSLocalizedString("Tweets from everyone you follow", comment: "Home Timeline")
			screenSearchTextField.isHidden = true
			addButton.isEnabled = true
			
		case 1:
			
			accountLabel.isHidden = false
			accountPopupButton.isHidden = false
			typeDescriptionLabel.stringValue = NSLocalizedString("Tweets mentioning you", comment: "Mentions")
			screenSearchTextField.isHidden = true
			addButton.isEnabled = true
			
		case 2:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			
			var screenName = screenSearchTextField.stringValue
			if !screenName.isEmpty && !screenName.starts(with: "@") {
				screenName = "@\(screenName)"
				typeDescriptionLabel.stringValue = NSLocalizedString("Tweets from \(screenName)", comment: "Home Timeline")
			} else {
				typeDescriptionLabel.stringValue = ""
			}
			
			screenSearchTextField.placeholderString = NSLocalizedString("@name", comment: "@name")
			screenSearchTextField.isHidden = false
			addButton.isEnabled = !screenSearchTextField.stringValue.isEmpty
			
		default:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			
			if !screenSearchTextField.stringValue.isEmpty {
				typeDescriptionLabel.stringValue = NSLocalizedString("Tweets that contain \(screenSearchTextField.stringValue)", comment: "Home Timeline")
			} else {
				typeDescriptionLabel.stringValue = ""
			}
			
			screenSearchTextField.placeholderString = nil
			screenSearchTextField.isHidden = false
			addButton.isEnabled = !screenSearchTextField.stringValue.isEmpty
			
		}
		
		addButton.isEnabled = !screenSearchTextField.stringValue.isEmpty
	}

	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
