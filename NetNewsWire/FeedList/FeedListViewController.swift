//
//  FeedListViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSTree
import RSCore

extension Notification.Name {

	static let FeedListSidebarSelectionDidChange = Notification.Name(rawValue: "FeedListSidebarSelectionDidChange")
}

struct FeedListUserInfoKey {

	static let selectedObject = "selectedObject"
}

final class FeedListViewController: NSViewController {

	@IBOutlet weak var outlineView: NSOutlineView!
	@IBOutlet weak var openHomePageButton: NSButton!
	@IBOutlet weak var addToFeedsButton: NSButton!
    @IBOutlet weak var folderPopupButton: NSPopUpButton!
    
	fileprivate var folderTreeController: TreeController?
	private var sidebarCellAppearance: SidebarCellAppearance!
	private let treeControllerDelegate = FeedListTreeControllerDelegate()
	lazy var treeController: TreeController = {
		TreeController(delegate: treeControllerDelegate)
	}()

	private var selectedNodes: [Node] {
		if let nodes = outlineView.selectedItems as? [Node] {
			return nodes
		}
		return [Node]()
	}

	private var selectedObjects: [AnyObject] {
		return selectedNodes.representedObjects()
	}

	// MARK: NSViewController

	override func viewDidLoad() {

		view.translatesAutoresizingMaskIntoConstraints = false

		sidebarCellAppearance = SidebarCellAppearance(theme: appDelegate.currentTheme, fontSize: AppDefaults.shared.sidebarFontSize)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(childrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		
		outlineView.needsLayout = true

		updateFolderMenu()
		updateButtons()
		
	}

	// MARK: - Notifications
	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		configureAvailableCells()
	}
	
	@objc func childrenDidChange(_ note: Notification) {
		updateFolderMenu()
	}
	
}

// MARK: Actions

extension FeedListViewController {

	@IBAction func openHomePage(_ sender: Any?) {

		guard let homePageURL = singleSelectedHomePageURL() else {
			return
		}
		Browser.open(homePageURL, inBackground: false)
	}

	@IBAction func addToFeeds(_ sender: Any?) {

		guard let container = folderPopupButton.selectedItem?.representedObject as? Container else {
			assertionFailure("Expected the folderPopupButton to have a container.")
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
		
		for selectedObject in selectedObjects {
			
			guard let feedListFeed = selectedObject as? FeedListFeed else {
				continue
			}
			
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
		
	}
}

// MARK: - NSOutlineViewDataSource

extension FeedListViewController: NSOutlineViewDataSource {

	func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
		
		return nodeForItem(item as AnyObject?).numberOfChildNodes
	}

	func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {

		return nodeForItem(item as AnyObject?).childNodes[index]
	}

	func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {

		return nodeForItem(item as AnyObject?).canHaveChildNodes
	}

	private func nodeForItem(_ item: AnyObject?) -> Node {

		if item == nil {
			return treeController.rootNode
		}
		return item as! Node
	}
}

// MARK: - NSOutlineViewDelegate

extension FeedListViewController: NSOutlineViewDelegate {

	func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {

		let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "FeedListCell"), owner: self) as! SidebarCell
		cell.translatesAutoresizingMaskIntoConstraints = false
		let node = item as! Node
		configure(cell, node)

		return cell
	}

	func outlineViewSelectionDidChange(_ notification: Notification) {

		updateButtons()
		
		let selectedRow = self.outlineView.selectedRow

		if selectedRow < 0 || selectedRow == NSNotFound {
			postSidebarSelectionDidChangeNotification(nil)
			return
		}

		if let selectedNode = self.outlineView.item(atRow: selectedRow) as? Node {
			postSidebarSelectionDidChangeNotification(selectedNode.representedObject)
		}
	}
}

private extension FeedListViewController {

	func configure(_ cell: SidebarCell, _ node: Node) {

		cell.cellAppearance = sidebarCellAppearance
		cell.objectValue = node
		cell.name = nameFor(node)
		cell.image = imageFor(node)
		cell.shouldShowImage = true
	}

	func imageFor(_ node: Node) -> NSImage? {

		if let _ = node.representedObject as? FeedListFolder {
			return NSImage(named: NSImage.Name.folder)
		}
		else if let feed = node.representedObject as? FeedListFeed {
			if let image = appDelegate.faviconDownloader.favicon(withHomePageURL: feed.homePageURL) {
				return image
			}
			return AppImages.genericFeedImage
		}
		return nil
	}

	func nameFor(_ node: Node) -> String {

		if let displayNameProvider = node.representedObject as? DisplayNameProvider {
			return displayNameProvider.nameForDisplay
		}
		return ""
	}

	func nodeForRow(_ row: Int) -> Node? {

		if row < 0 || row >= outlineView.numberOfRows {
			return nil
		}

		if let node = outlineView.item(atRow: row) as? Node {
			return node
		}
		return nil
	}

	func cellForRowView(_ rowView: NSTableRowView) -> SidebarCell? {

		return rowView.view(atColumn: 0) as? SidebarCell
	}

	func configureAvailableCells() {

		outlineView.enumerateAvailableRowViews { (rowView: NSTableRowView, row: Int) -> Void in

			guard let cell = cellForRowView(rowView), let node = nodeForRow(row) else {
				return
			}
			configure(cell, node)
		}
	}

	func postSidebarSelectionDidChangeNotification(_ selectedObject: Any?) {

		var userInfo = [AnyHashable: Any]()

		if let selectedObject = selectedObject {
			userInfo[FeedListUserInfoKey.selectedObject] = selectedObject
		}

		NotificationCenter.default.post(name: .FeedListSidebarSelectionDidChange, object: self, userInfo: userInfo)
	}

	func updateFolderMenu() {
		
		let rootNode = Node(representedObject: AccountManager.shared.localAccount, parent: nil)
		rootNode.canHaveChildNodes = true
		folderTreeController = TreeController(delegate: FolderTreeControllerDelegate(), rootNode: rootNode)
		
		folderPopupButton.menu = FolderTreeMenu.createFolderPopupMenu(with: folderTreeController!.rootNode)
	}
	
	func updateButtons() {

		let objects = selectedObjects

		if objects.isEmpty {
			openHomePageButton.isEnabled = false
			addToFeedsButton.isEnabled = false
			folderPopupButton.isEnabled = false
			return
		}

		addToFeedsButton.isEnabled = true
		folderPopupButton.isEnabled = true

		if let _ = singleSelectedHomePageURL() {
			openHomePageButton.isEnabled = true
		}
		else {
			openHomePageButton.isEnabled = false
		}
	}

	func singleSelectedHomePageURL() -> String? {

		guard selectedObjects.count == 1, let homePageURL = (selectedObjects.first! as? FeedListFeed)?.homePageURL, !homePageURL.isEmpty else {
			return nil
		}
		return homePageURL
	}
}
