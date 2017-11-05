//
//  DeleteFromSidebarCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 11/4/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import RSTree
import Account
import Data

final class DeleteFromSidebarCommand: UndoableCommand {

	private struct ActionName {
		static private let deleteFeed = NSLocalizedString("Delete Feed", comment: "command")
		static private let deleteFeeds = NSLocalizedString("Delete Feeds", comment: "command")
		static private let deleteFolder = NSLocalizedString("Delete Folder", comment: "command")
		static private let deleteFolders = NSLocalizedString("Delete Folders", comment: "command")
		static private let deleteFeedsAndFolders = NSLocalizedString("Delete Feeds and Folders", comment: "command")
	}

	let undoActionName: String
	var redoActionName: String {
		get {
			return undoActionName
		}
	}

	let undoManager: UndoManager

	init?(nodesToDelete: [Node], undoManager: UndoManager) {

		var numberOfFeeds = 0
		var numberOfFolders = 0

		for node in nodesToDelete {
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

		if numberOfFeeds < 1 && numberOfFolders < 1 {
			return nil
		}

		if numberOfFolders < 1 {
			self.undoActionName = numberOfFeeds == 1 ? ActionName.deleteFeed : ActionName.deleteFeeds
		}
		else if numberOfFeeds < 1 {
			self.undoActionName = numberOfFolders == 1 ? ActionName.deleteFolder : ActionName.deleteFolders
		}
		else {
			self.undoActionName = ActionName.deleteFeedsAndFolders
		}

		self.undoManager = undoManager
	}

	func perform() {

		registerUndo()
	}

	func undo() {

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

	weak var account: Account?
	let node: Node
	let folder: Folder?
	let feed: Feed?
	let path: ContainerPath

	init?(node: Node) {

		self.node = node

		var account: Account?
		if let feed = node.representedObject as? Feed {
			self.feed = feed
			account = feed.account
		}
		else if let folder = node.representedObject as? Folder {
			self.folder = folder
			account = folder.account
		}

		guard let account = account else {
			return nil
		}

		self.account = account
		self.path = SidebarPath(account: account, node: node)
	}
}

