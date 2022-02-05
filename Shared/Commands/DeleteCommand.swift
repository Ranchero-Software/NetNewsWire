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

	let treeController: TreeController?
	let undoManager: UndoManager
	let undoActionName: String
	var redoActionName: String {
		return undoActionName
	}
	let errorHandler: (Error) -> ()

	private let itemSpecifiers: [SidebarItemSpecifier]

	init?(nodesToDelete: [Node], treeController: TreeController? = nil, undoManager: UndoManager, errorHandler: @escaping (Error) -> ()) {

		guard DeleteCommand.canDelete(nodesToDelete) else {
			return nil
		}
		guard let actionName = DeleteActionName.name(for: nodesToDelete) else {
			return nil
		}

		self.treeController = treeController
		self.undoActionName = actionName
		self.undoManager = undoManager
		self.errorHandler = errorHandler

		let itemSpecifiers = nodesToDelete.compactMap{ SidebarItemSpecifier(node: $0, errorHandler: errorHandler) }
		guard !itemSpecifiers.isEmpty else {
			return nil
		}
		self.itemSpecifiers = itemSpecifiers
	}

	func perform() {
		
		let group = DispatchGroup()
		itemSpecifiers.forEach {
			group.enter()
			$0.delete() {
				group.leave()
			}
		}
	
		group.notify(queue: DispatchQueue.main) {
			self.treeController?.rebuild()
			self.registerUndo()
		}
		
	}
	
	func undo() {
		itemSpecifiers.forEach { $0.restore() }
		registerRedo()
	}

	static func canDelete(_ nodes: [Node]) -> Bool {

		// Return true if all nodes are feeds and folders.
		// Any other type: return false.

		if nodes.isEmpty {
			return false
		}

		for node in nodes {
			if let _ = node.representedObject as? WebFeed {
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
	private let webFeed: WebFeed?
	private let path: ContainerPath
	private let errorHandler: (Error) -> ()

	private var container: Container? {
		if let parentFolder = parentFolder {
			return parentFolder
		}
		if let account = account {
			return account
		}
		return nil
	}

	init?(node: Node, errorHandler: @escaping (Error) -> ()) {

		var account: Account?

		self.parentFolder = node.parentFolder()

		if let webFeed = node.representedObject as? WebFeed {
			self.webFeed = webFeed
			self.folder = nil
			account = webFeed.account
		}
		else if let folder = node.representedObject as? Folder {
			self.webFeed = nil
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
		
		self.errorHandler = errorHandler
		
	}

	func delete(completion: @escaping () -> Void) {

		if let webFeed = webFeed {
			
			guard let container = path.resolveContainer() else {
				completion()
				return
			}
			
			BatchUpdate.shared.start()
			account?.removeWebFeed(webFeed, from: container) { result in
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

		if let _ = webFeed {
			restoreWebFeed()
		}
		else if let _ = folder {
			restoreFolder()
		}
	}

	private func restoreWebFeed() {

		guard let account = account, let feed = webFeed, let container = path.resolveContainer() else {
			return
		}
		
		BatchUpdate.shared.start()
		account.restoreWebFeed(feed, container: container) { result in
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
			errorHandler(error)
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

	private static let deleteFeed = NSLocalizedString("DELETE_FEED", comment: "command")
	private static let deleteFeeds = NSLocalizedString("DELETE_FEEDS", comment: "command")
	private static let deleteFolder = NSLocalizedString("DELETE_FOLDER", comment: "command")
	private static let deleteFolders = NSLocalizedString("DELETE_FOLDERS", comment: "command")
	private static let deleteFeedsAndFolders = NSLocalizedString("DELETE_FEEDS_AND_FOLDERS", comment: "command")

	static func name(for nodes: [Node]) -> String? {

		var numberOfFeeds = 0
		var numberOfFolders = 0

		for node in nodes {
			if let _ = node.representedObject as? WebFeed {
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
