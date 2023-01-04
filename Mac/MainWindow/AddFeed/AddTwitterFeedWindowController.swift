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

	private weak var delegate: AddFeedWindowControllerDelegate?
	private var folderTreeController: TreeController!

	private var userEnteredScreenSearch: String? {
		var s = screenSearchTextField.stringValue
		s = s.collapsingWhitespace
		if s.isEmpty {
			return nil
		}
		return s
	}
	
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

		let accountMenu = NSMenu()
		for feedProvider in ExtensionPointManager.shared.activeFeedProviders {
			if let twitterFeedProvider = feedProvider as? TwitterFeedProvider {
				let accountMenuItem = NSMenuItem()
				accountMenuItem.title = "@\(twitterFeedProvider.screenName)"
				accountMenu.addItem(accountMenuItem)
			}
		}
		accountPopupButton.menu = accountMenu
		
		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController.rootNode, restrictToSpecialAccounts: true)
		
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
		guard let type = TwitterFeedType(rawValue: typePopupButton.selectedItem?.tag ?? 0),
			let atUsername = accountPopupButton.selectedItem?.title else { return }
		
		let username = String(atUsername[atUsername.index(atUsername.startIndex, offsetBy: 1)..<atUsername.endIndex])

		var screenSearch = userEnteredScreenSearch
		if let screenName = screenSearch, type == .screenName && screenName.starts(with: "@") {
			screenSearch = String(screenName[screenName.index(screenName.startIndex, offsetBy: 1)..<screenName.endIndex])
		}

		guard let url = TwitterFeedProvider.buildURL(type, username: username, screenName: screenSearch, searchField: screenSearch) else { return }
		
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
			typeDescriptionLabel.stringValue = NSLocalizedString("label.text.tweets-from-everyone", comment: "Tweets from everyone you follow")
			screenSearchTextField.isHidden = true
			addButton.isEnabled = true
			
		case 1:
			
			accountLabel.isHidden = false
			accountPopupButton.isHidden = false
			typeDescriptionLabel.stringValue = NSLocalizedString("label.text.tweets-mentioning-you", comment: "Tweets mentioning you")
			screenSearchTextField.isHidden = true
			addButton.isEnabled = true
			
		case 2:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			
			var screenSearch = userEnteredScreenSearch
			if screenSearch != nil {
				if let screenName = screenSearch, screenName.starts(with: "@") {
					screenSearch = String(screenName[screenName.index(screenName.startIndex, offsetBy: 1)..<screenName.endIndex])
				}
				let tweets = NSLocalizedString("label.text.tweets-from.%@", comment: "Tweets from @%@")
				typeDescriptionLabel.stringValue = String(format: tweets, screenSearch!)
			} else {
				typeDescriptionLabel.stringValue = ""
			}
			
			screenSearchTextField.placeholderString = NSLocalizedString("textfield.placeholder.twitter-username", comment: "@name")
			screenSearchTextField.isHidden = false
			addButton.isEnabled = !screenSearchTextField.stringValue.isEmpty
			
		default:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			
			if !screenSearchTextField.stringValue.isEmpty {
				let tweets = NSLocalizedString("label.text.tweets-containing.%@", comment: "Tweets that contain %@")
				typeDescriptionLabel.stringValue = String(format: tweets, screenSearchTextField.stringValue)
			} else {
				typeDescriptionLabel.stringValue = ""
			}
			
			screenSearchTextField.placeholderString = NSLocalizedString("textfield.placeholder.search-term-hashtag", comment: "Search Term or #hashtag")
			screenSearchTextField.isHidden = false
			addButton.isEnabled = !screenSearchTextField.stringValue.isEmpty
			
		}
		
	}

	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
