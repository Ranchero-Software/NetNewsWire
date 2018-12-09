//
//  FeedListViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/1/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSTree
import RSCore

extension Notification.Name {

	static let FeedListSidebarSelectionDidChange = Notification.Name(rawValue: "FeedListSidebarSelectionDidChange")
}

struct FeedListUserInfoKey {

	static let selectedObject = "selectedObject"
}

final class FeedListViewController: NSViewController {

	@IBOutlet var outlineView: NSOutlineView!
	@IBOutlet var openHomePageButton: NSButton!
	@IBOutlet var addToFeedsButton: NSButton!
	
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
		outlineView.needsLayout = true
		updateUI()
	}

	// MARK: - Notifications

	@objc func faviconDidBecomeAvailable(_ note: Notification) {

		configureAvailableCells()
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
		let selectedFeeds = selectedObjects.map { $0 as! FeedListFeed }
		appDelegate.showAddFeedFromListOnMainWindow(selectedFeeds)
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

		updateUI()

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
			return NSImage(named: NSImage.folderName)
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

	func updateUI() {

		updateButtons()
	}

	func updateButtons() {

		let objects = selectedObjects

		if objects.isEmpty {
			openHomePageButton.isEnabled = false
			addToFeedsButton.isEnabled = false
			return
		}

		addToFeedsButton.isEnabled = true

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
