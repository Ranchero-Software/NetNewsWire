//
//  DeleteFromSidebarCommand.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSTree
import Account
import Articles

final class DeleteCommand: UndoableCommand {

	let treeController: TreeController
	let undoManager: UndoManager
	let undoActionName: String
	var redoActionName: String {
		return undoActionName
	}

	private let itemSpecifiers: [SidebarItemSpecifier]

	init?(nodesToDelete: [Node], treeController: TreeController, undoManager: UndoManager) {

		guard DeleteCommand.canDelete(nodesToDelete) else {
			return nil
		}
		guard let actionName = DeleteActionName.name(for: nodesToDelete) else {
			return nil
		}

		self.treeController = treeController
		self.undoActionName = actionName
		self.undoManager = undoManager

		let itemSpecifiers = nodesToDelete.compactMap{ SidebarItemSpecifier(node: $0) }
		guard !itemSpecifiers.isEmpty else {
			return nil
		}
		self.itemSpecifiers = itemSpecifiers
	}

	func perform() {

		BatchUpdate.shared.perform {
			itemSpecifiers.forEach { $0.delete() {} }
			treeController.rebuild()
		}
		registerUndo()
	}

	func perform(completion: @escaping () -> Void) {
		
		let group = DispatchGroup()
		group.enter()
		itemSpecifiers.forEach {
			$0.delete() {
				group.leave()
			}
		}
		treeController.rebuild()
	
		group.notify(queue: DispatchQueue.main) {
			self.registerUndo()
			completion()
		}
		
	}
	
	func undo() {

		BatchUpdate.shared.perform {
			itemSpecifiers.forEach { $0.restore() }
			treeController.rebuild()
		}
		registerRedo()
	}

	static func canDelete(_ nodes: [Node]) -> Bool {

		// Return true if all nodes are feeds and folders.
		// Any other type: return false.

		if nodes.isEmpty {
			return false
		}

		for node in nodes {
			if let _ = node.representedObject as? Feed {
				continue
			}
			if let _ = node.representedObject as? Folder {
				continue
			}
			return false
		}

		return true
	}
}

// Remember as much as we can now about the items being deleted,
// so they can be restored to the correct place.

private struct SidebarItemSpecifier {

	private weak var account: Account?
	private let parentFolder: Folder?
	private let folder: Folder?
	private let feed: Feed?
	private let path: ContainerPath

	private var container: Container? {
		if let parentFolder = parentFolder {
			return parentFolder
		}
		if let account = account {
			return account
		}
		return nil
	}

	init?(node: Node) {

		var account: Account?

		self.parentFolder = node.parentFolder()

		if let feed = node.representedObject as? Feed {
			self.feed = feed
			self.folder = nil
			account = feed.account
		}
		else if let folder = node.representedObject as? Folder {
			self.feed = nil
			self.folder = folder
			account = folder.account
		}
		else {
			return nil
		}
		if account == nil {
			return nil
		}

		self.account = account!
		self.path = ContainerPath(account: account!, folders: node.containingFolders())
	}

	func delete(completion: @escaping () -> Void) {

		if let feed = feed {
			BatchUpdate.shared.start()
			account?.removeFeed(feed, from: path.resolveContainer()) { result in
				BatchUpdate.shared.end()
				completion()
				self.checkResult(result)
			}
		} else if let folder = folder {
			BatchUpdate.shared.start()
			account?.removeFolder(folder) { result in
				BatchUpdate.shared.end()
				completion()
				self.checkResult(result)
			}
		}
	}

	func restore() {

		if let _ = feed {
			restoreFeed()
		}
		else if let _ = folder {
			restoreFolder()
		}
	}

	private func restoreFeed() {

		guard let account = account, let feed = feed, let container = path.resolveContainer() else {
			return
		}
		
		BatchUpdate.shared.start()
		account.restoreFeed(feed, container: container) { result in
			BatchUpdate.shared.end()
			self.checkResult(result)
		}
		
	}

	private func restoreFolder() {

		guard let account = account, let folder = folder else {
			return
		}
		
		BatchUpdate.shared.start()
		account.restoreFolder(folder) { result in
			BatchUpdate.shared.end()
			self.checkResult(result)
		}
		
	}

	private func checkResult(_ result: Result<Void, Error>) {
		
		switch result {
		case .success:
			break
		case .failure(let error):
			#if os(macOS)
			NSApplication.shared.presentError(error)
			#else
			UIApplication.shared.presentError(error)
			#endif
		}

	}
	
}

private extension Node {
	
	func parentFolder() -> Folder? {

		guard let parentNode = self.parent else {
			return nil
		}
		if parentNode.isRoot {
			return nil
		}
		if let folder = parentNode.representedObject as? Folder {
			return folder
		}
		return nil
	}

	func containingFolders() -> [Folder] {

		var nomad = self.parent
		var folders = [Folder]()

		while nomad != nil {
			if let folder = nomad!.representedObject as? Folder {
				folders += [folder]
			}
			else {
				break
			}
			nomad = nomad!.parent
		}

		return folders.reversed()
	}

}

private struct DeleteActionName {

	private static let deleteFeed = NSLocalizedString("Delete Feed", comment: "command")
	private static let deleteFeeds = NSLocalizedString("Delete Feeds", comment: "command")
	private static let deleteFolder = NSLocalizedString("Delete Folder", comment: "command")
	private static let deleteFolders = NSLocalizedString("Delete Folders", comment: "command")
	private static let deleteFeedsAndFolders = NSLocalizedString("Delete Feeds and Folders", comment: "command")

	static func name(for nodes: [Node]) -> String? {

		var numberOfFeeds = 0
		var numberOfFolders = 0

		for node in nodes {
			if let _ = node.representedObject as? Feed {
				numberOfFeeds += 1
			}
			else if let _ = node.representedObject as? Folder {
				numberOfFolders += 1
			}
			else {
				return nil // Delete only Feeds and Folders.
			}
		}

		if numberOfFolders < 1 {
			return numberOfFeeds == 1 ? deleteFeed : deleteFeeds
		}
		if numberOfFeeds < 1 {
			return numberOfFolders == 1 ? deleteFolder : deleteFolders
		}

		return deleteFeedsAndFolders
	}
}
