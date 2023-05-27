//
//  AddRedditFeedWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/10/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account

@MainActor final class AddRedditFeedWindowController : NSWindowController, AddFeedWindowController {

	@IBOutlet weak var typePopupButton: NSPopUpButton!
	@IBOutlet weak var typeDescriptionLabel: NSTextField!

	@IBOutlet weak var accountLabel: NSTextField!
	@IBOutlet weak var accountPopupButton: NSPopUpButton!
	@IBOutlet weak var subredditTextField: NSTextField!

	@IBOutlet weak var typeToSortLayoutConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var sortPopupButton: NSPopUpButton!
	
	@IBOutlet var nameTextField: NSTextField!
	@IBOutlet var addButton: NSButton!
	@IBOutlet var folderPopupButton: NSPopUpButton!

	private weak var delegate: AddFeedWindowControllerDelegate?
	private var folderTreeController: TreeController!

	private var userSelectedSort: RedditSort {
		switch sortPopupButton.selectedItem?.tag ?? 0 {
		case 0:
			return .best
		case 1:
			return .hot
		case 2:
			return .new
		case 3:
			return .top
		default:
			return .rising
		}
	}
	
	private var userEnteredSubreddit: String? {
		var s = subredditTextField.stringValue
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
		self.init(windowNibName: NSNib.Name("AddRedditFeedSheet"))
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
			if let redditFeedProvider = feedProvider as? RedditFeedProvider {
				let accountMenuItem = NSMenuItem()
				accountMenuItem.title = redditFeedProvider.title
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
		subredditTextField.stringValue = ""
		updateUI()
	}

	@IBAction func cancel(_ sender: Any?) {
		cancelSheet()
    }
    
    @IBAction func addFeed(_ sender: Any?) {
		guard let type = RedditFeedType(rawValue: typePopupButton.selectedItem?.tag ?? 0),
			let atUsername = accountPopupButton.selectedItem?.title else { return }
		
		let username = String(atUsername[atUsername.index(atUsername.startIndex, offsetBy: 2)..<atUsername.endIndex])
		guard let url = RedditFeedProvider.buildURL(type, username: username, subreddit: userEnteredSubreddit, sort: userSelectedSort) else { return }
		
		let container = selectedContainer()!
		AddWebFeedDefaultContainer.saveDefaultContainer(container)
		delegate?.addFeedWindowController(self, userEnteredURL: url, userEnteredTitle: userEnteredTitle, container: container)
    }
	
}

extension AddRedditFeedWindowController: NSTextFieldDelegate {

	func controlTextDidChange(_ obj: Notification) {
		updateUI()
	}
	
}

private extension AddRedditFeedWindowController {
	
	private func updateUI() {
		
		switch typePopupButton.selectedItem?.tag ?? 0 {
		case 0:
			
			animateShowHideFields(collapsed: false) {
				self.accountLabel.isHidden = false
				self.accountPopupButton.isHidden = false
				self.typeDescriptionLabel.stringValue = NSLocalizedString("label.text.reddit-front-page", comment: "Your personal Reddit frontpage")
				self.subredditTextField.isHidden = true
				self.addButton.isEnabled = true
			}
			
		case 1:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			typeDescriptionLabel.stringValue = NSLocalizedString("label.text.reddit-best-posts", comment: "The best posts on Reddit for you")
			subredditTextField.isHidden = true
			addButton.isEnabled = true
			animateShowHideFields(collapsed: true)

		case 2:
			
			accountLabel.isHidden = true
			accountPopupButton.isHidden = true
			typeDescriptionLabel.stringValue = NSLocalizedString("label.text.reddit-active-posts", comment: "The most active posts")
			subredditTextField.isHidden = true
			addButton.isEnabled = true
			animateShowHideFields(collapsed: true)

		default:
			
			animateShowHideFields(collapsed: false) {
				self.accountLabel.isHidden = true
				self.accountPopupButton.isHidden = true
				
				if !self.subredditTextField.stringValue.isEmpty {
					let subreddit = NSLocalizedString("label.text.posts-from-subreddit.%@", comment: "Posts from r/%@")
					self.typeDescriptionLabel.stringValue = String(format: subreddit, self.subredditTextField.stringValue)
				} else {
					self.typeDescriptionLabel.stringValue = ""
				}
				
				self.subredditTextField.placeholderString = NSLocalizedString("label.text.subreddit", comment: "Subreddit")
				self.subredditTextField.isHidden = false
				self.addButton.isEnabled = !self.subredditTextField.stringValue.isEmpty
			}
			
		}
		
	}
	
	func animateShowHideFields(collapsed: Bool, completion: (() -> Void)? = nil) {
		let constant: CGFloat = collapsed ? 8 : 39
		
		NSAnimationContext.beginGrouping()
		NSAnimationContext.current.duration = 0.2
		NSAnimationContext.current.completionHandler = completion
		typeToSortLayoutConstraint.animator().constant = constant
		NSAnimationContext.endGrouping()
	}
	
	func cancelSheet() {
		delegate?.addFeedWindowControllerUserDidCancel(self)
	}

	func selectedContainer() -> Container? {
		return folderPopupButton.selectedItem?.representedObject as? Container
	}
}
