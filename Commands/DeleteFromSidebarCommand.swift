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
		static let deleteFeed = NSLocalizedString("Delete Feed", comment: "command")
		static let deleteFeeds = NSLocalizedString("Delete Feeds", comment: "command")
		static let deleteFolder = NSLocalizedString("Delete Folder", comment: "command")
		static let deleteFolders = NSLocalizedString("Delete Folders", comment: "command")
		static let deleteFeedsAndFolders = NSLocalizedString("Delete Feeds and Folders", comment: "command")
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
	let folder: Folder?
	let feed: Feed?
	let path: ContainerPath

	init?(node: Node) {

		var account: Account?
        
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
}

private extension Node {
    
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

