//
//  AddFeedFromListWindowController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/13/18.
//  Copyright © 2018 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore
import RSTree
import Articles
import Account


class AddFeedFromListWindowController : NSWindowController {
	
    @IBOutlet weak var addFeedTextField: NSTextField!
    @IBOutlet weak var folderPopupButton: NSPopUpButton!
	
	private var feedListFeeds: [FeedListFeed]?
    private var hostWindow: NSWindow!
	private var folderTreeController: TreeController?

	convenience init(_ feedListFeeds: [FeedListFeed]) {
		self.init(windowNibName: NSNib.Name(rawValue: "AddFeedFromListSheet"))
		self.feedListFeeds = feedListFeeds
	}
	
    func runSheetOnWindow(_ w: NSWindow) {
        hostWindow = w
		if let sheetWindow = self.window {
        	hostWindow.beginSheet(sheetWindow) { (returnCode: NSApplication.ModalResponse) -> Void in
			}
		}
    }

	override func windowDidLoad() {

		guard let feedListFeeds = feedListFeeds else {
			assertionFailure("Feeds should have been passed in the initializer")
			return
		}
		
		if feedListFeeds.count == 1 {
			addFeedTextField.stringValue = "Add \"\(feedListFeeds.first!.nameForDisplay)\"?"
		} else {
			addFeedTextField.stringValue = "Add \(feedListFeeds.count) feeds?"
		}
		
		let rootNode = Node(representedObject: AccountManager.shared.localAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		folderTreeController = TreeController(delegate: FolderTreeControllerDelegate(), rootNode: rootNode)
		
		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController!.rootNode)

	}


    // MARK: Actions
    
    @IBAction func cancel(_ sender: Any?) {
		if let sheetWindow = window {
			hostWindow.endSheet(sheetWindow, returnCode: NSApplication.ModalResponse.cancel)
		}
    }
    
    @IBAction func addFeed(_ sender: Any?) {
		
		guard let container = folderPopupButton.selectedItem?.representedObject as? Container else {
			assertionFailure("Expected the folderPopupButton to have a container.")
			return
		}

		guard let feedListFeeds = feedListFeeds else {
			assertionFailure("Feeds should have been passed in the initializer")
			return
		}
		
		var account: Account?
		var folder: Folder?
		if container is Folder {
			folder = (container as! Folder)
			account = folder!.account
		} else {
			account = (container as! Account)
		}
		
		for feedListFeed in feedListFeeds {
			
			if account!.hasFeed(withURL: feedListFeed.url) {
				continue
			}
			
			guard let feed = account!.createFeed(with: feedListFeed.nameForDisplay, editedName: nil, url: feedListFeed.url) else {
				continue
			}
			
			guard let url = URL(string: feedListFeed.url) else {
				assertionFailure("Malformed URL string: \(feedListFeed.url).")
				continue
			}
			
			if account!.addFeed(feed, to: folder) {
				NotificationCenter.default.post(name: .UserDidAddFeed, object: self, userInfo: [UserInfoKey.feed: feed])
			}
			
			InitialFeedDownloader.download(url) { (parsedFeed) in
				if let parsedFeed = parsedFeed {
					account!.update(feed, with: parsedFeed, {})
				}
			}
			
		}
		
		if let sheetWindow = window {
			hostWindow.endSheet(sheetWindow, returnCode: NSApplication.ModalResponse.OK)
		}
		
	}

}
