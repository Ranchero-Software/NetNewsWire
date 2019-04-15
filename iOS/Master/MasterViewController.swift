//
//  MasterViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import RSCore
import RSTree

class MasterViewController: UITableViewController {

	var animatingChanges = false
	
	let treeControllerDelegate = MasterTreeControllerDelegate()
	lazy var treeController: TreeController = {
		return TreeController(delegate: treeControllerDelegate)
	}()
	
	override func viewDidLoad() {

		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(containerChildrenDidChange(_:)), name: .ChildrenDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(batchUpdateDidPerform(_:)), name: .BatchUpdateDidPerform, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(feedSettingDidChange(_:)), name: .FeedSettingDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(displayNameDidChange(_:)), name: .DisplayNameDidChange, object: nil)

		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)

		refreshControl = UIRefreshControl()
		refreshControl!.addTarget(self, action: #selector(refreshAccounts(_:)), for: .valueChanged)
		
	}

	override func viewWillAppear(_ animated: Bool) {
		clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
		super.viewWillAppear(animated)
	}

	@objc private func refreshAccounts(_ sender: Any) {
		AccountManager.shared.refreshAll()
	}

	@objc dynamic func progressDidChange(_ notification: Notification) {
		if AccountManager.shared.combinedRefreshProgress.isComplete {
			refreshControl?.endRefreshing()
		} else {
			refreshControl?.beginRefreshing()
		}
	}

	@objc func containerChildrenDidChange(_ note: Notification) {
		rebuildTreeAndReloadDataIfNeeded()
	}
	
	@objc func batchUpdateDidPerform(_ notification: Notification) {
		rebuildTreeAndReloadDataIfNeeded()
	}
	
	@objc func unreadCountDidChange(_ note: Notification) {
		guard let representedObject = note.object else {
			return
		}
		configureUnreadCountForCellsForRepresentedObject(representedObject as AnyObject)
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		applyToAvailableCells(configureFavicon)
	}

	@objc func feedSettingDidChange(_ note: Notification) {
		
		guard let feed = note.object as? Feed, let key = note.userInfo?[Feed.FeedSettingUserInfoKey] as? String else {
			return
		}
		
		if key == Feed.FeedSettingKey.homePageURL || key == Feed.FeedSettingKey.faviconURL {
			configureCellsForRepresentedObject(feed)
		}
		
	}
	
	@objc func displayNameDidChange(_ note: Notification) {
		
		guard let object = note.object else {
			return
		}
		
		rebuildTreeAndReloadDataIfNeeded()
		configureCellsForRepresentedObject(object as AnyObject)
		
	}

	// MARK: Table View
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! MasterTableViewCell
		
		guard let node = nodeFor(indexPath: indexPath) else {
			return cell
		}
		
		configure(cell, node)
		return cell

	}
	
	override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
		guard let node = nodeFor(indexPath: indexPath), !(node.representedObject is PseudoFeed) else {
			return false
		}
		return true
	}
	
	override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
		
		// Set up the delete action
		let deleteTitle = NSLocalizedString("Delete", comment: "Delete")
		let deleteAction = UIContextualAction(style: .normal, title: deleteTitle) { [weak self] (action, view, completionHandler) in
			self?.delete(indexPath: indexPath)
			completionHandler(true)
		}
		
		deleteAction.backgroundColor = UIColor.red
		
		// Set up the rename action
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIContextualAction(style: .normal, title: renameTitle) { [weak self] (action, view, completionHandler) in
			self?.rename(indexPath: indexPath)
			completionHandler(true)
		}
		
		renameAction.backgroundColor = UIColor.gray
		
		return UISwipeActionsConfiguration(actions: [deleteAction, renameAction])
		
	}

	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		
		guard let node = nodeFor(indexPath: indexPath) else {
			assertionFailure()
			return
		}
		
		if let pseudoFeed = node.representedObject as? PseudoFeed {
			let timeline = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			timeline.title = pseudoFeed.nameForDisplay
			timeline.representedObjects = [pseudoFeed]
			self.navigationController?.pushViewController(timeline, animated: true)
		}
		
		if let folder = node.representedObject as? Folder {
			let secondary = UIStoryboard.main.instantiateController(ofType: MasterSecondaryViewController.self)
			secondary.title = folder.nameForDisplay
			secondary.viewRootNode = node
			self.navigationController?.pushViewController(secondary, animated: true)
		}
		
		if let feed = node.representedObject as? Feed {
			let timeline = UIStoryboard.main.instantiateController(ofType: MasterTimelineViewController.self)
			timeline.title = feed.nameForDisplay
			timeline.representedObjects = [feed]
			self.navigationController?.pushViewController(timeline, animated: true)
		}
		
	}
	
	// MARK: Actions
	
	@IBAction func addFeed(_ sender: UIBarButtonItem) {
		let feedViewController = UIStoryboard(name: "AddFeed", bundle: nil).instantiateViewController(withIdentifier: "AddFeedNavigationController")
		feedViewController.modalPresentationStyle = .popover
		feedViewController.popoverPresentationController?.barButtonItem = sender
		self.present(feedViewController, animated: true)
	}

	@IBAction func addFolder(_ sender: UIBarButtonItem) {
		let feedViewController = UIStoryboard(name: "AddFolder", bundle: nil).instantiateViewController(withIdentifier: "AddFolderNavigationController")
		feedViewController.modalPresentationStyle = .popover
		feedViewController.popoverPresentationController?.barButtonItem = sender
		self.present(feedViewController, animated: true)
	}
	
	// MARK: API
	
	func configure(_ cell: MasterTableViewCell, _ node: Node) {
		cell.name = nameFor(node)
		configureUnreadCount(cell, node)
		configureFavicon(cell, node)
		cell.shouldShowImage = node.representedObject is SmallIconProvider
	}
	
	func configureUnreadCount(_ cell: MasterTableViewCell, _ node: Node) {
		cell.unreadCount = unreadCountFor(node)
	}
	
	func configureFavicon(_ cell: MasterTableViewCell, _ node: Node) {
		cell.faviconImage = imageFor(node)
	}

	func imageFor(_ node: Node) -> UIImage? {
		if let smallIconProvider = node.representedObject as? SmallIconProvider {
			return smallIconProvider.smallIcon
		}
		return nil
	}
	
	func nameFor(_ node: Node) -> String {
		if let displayNameProvider = node.representedObject as? DisplayNameProvider {
			return displayNameProvider.nameForDisplay
		}
		return ""
	}
	
	func unreadCountFor(_ node: Node) -> Int {
		if let unreadCountProvider = node.representedObject as? UnreadCountProvider {
			return unreadCountProvider.unreadCount
		}
		return 0
	}
	
	func delete(indexPath: IndexPath) {
		assertionFailure()
	}

	func rename(indexPath: IndexPath) {
		
		let name = (nodeFor(indexPath: indexPath)?.representedObject as? DisplayNameProvider)?.nameForDisplay ?? ""
		let formatString = NSLocalizedString("Rename “%@”", comment: "Feed finder")
		let title = NSString.localizedStringWithFormat(formatString as NSString, name) as String
		
		let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
		
		let cancelTitle = NSLocalizedString("Cancel", comment: "Cancel")
		alertController.addAction(UIAlertAction(title: cancelTitle, style: .cancel))
		
		let renameTitle = NSLocalizedString("Rename", comment: "Rename")
		let renameAction = UIAlertAction(title: renameTitle, style: .default) { [weak self] action in
			
			guard let node = self?.nodeFor(indexPath: indexPath),
				let name = alertController.textFields?[0].text,
				!name.isEmpty else {
					return
			}
			
			if let feed = node.representedObject as? Feed {
				feed.editedName = name
			} else if let folder = node.representedObject as? Folder {
				folder.name = name
			}
			
		}
		
		alertController.addAction(renameAction)
		
		alertController.addTextField() { textField in
			textField.placeholder = NSLocalizedString("Name", comment: "Name")
		}
		
		self.present(alertController, animated: true) {
			
		}
		
	}

	func nodeFor(indexPath: IndexPath) -> Node? {
		assertionFailure()
		return nil
	}
	
}

// MARK: Private

private extension MasterViewController {
	
	func rebuildTreeAndReloadDataIfNeeded() {
		if !animatingChanges && !BatchUpdate.shared.isPerforming {
			treeController.rebuild()
			tableView.reloadData()
		}
	}
	
	func configureCellsForRepresentedObject(_ representedObject: AnyObject) {
		
		applyToCellsForRepresentedObject(representedObject, configure)
	}

	func configureUnreadCountForCellsForRepresentedObject(_ representedObject: AnyObject) {
		applyToCellsForRepresentedObject(representedObject, configureUnreadCount)
	}
	
	func applyToCellsForRepresentedObject(_ representedObject: AnyObject, _ callback: (MasterTableViewCell, Node) -> Void) {
		applyToAvailableCells { (cell, node) in
			if node.representedObject === representedObject {
				callback(cell, node)
			}
		}
	}
	
	func applyToAvailableCells(_ callback: (MasterTableViewCell, Node) -> Void) {
		tableView.visibleCells.forEach { cell in
			guard let indexPath = tableView.indexPath(for: cell), let node = nodeFor(indexPath: indexPath) else {
				return
			}
			callback(cell as! MasterTableViewCell, node)
		}
	}
	
}
