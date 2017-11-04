//
//  SidebarTreeControllerDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/24/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSTree
import Data
import Account

final class SidebarTreeControllerDelegate: TreeControllerDelegate {

	func treeController(treeController: TreeController, childNodesFor node: Node) -> [Node]? {
		
		if node.isRoot {
			return childNodesForRootNode(node)
		}
		if node.representedObject is Folder {
			return childNodesForFolderNode(node)
		}
		
		return nil
	}	
}

private extension SidebarTreeControllerDelegate {
	
	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {
		
		// The child nodes are the top-level items of the local Account.
		// This will be expanded later to add synthetic feeds (All Unread, for instance)
		// and other accounts.

		return childNodesForContainerNode(rootNode, AccountManager.shared.localAccount.children as! [AnyHashable])
	}

	func childNodesForFolderNode(_ folderNode: Node) -> [Node]? {

		let folder = folderNode.representedObject as! Folder
		return childNodesForContainerNode(folderNode, folder.children as! [AnyHashable])
	}

	func childNodesForContainerNode(_ containerNode: Node, _ children: [AnyHashable]) -> [Node]? {

		var updatedChildNodes = [Node]()

		children.forEach { (representedObject) in

			if let existingNode = containerNode.childNodeRepresentingObject(representedObject) {
				if !updatedChildNodes.contains(existingNode) {
					updatedChildNodes += [existingNode]
					return
				}
			}

			if let newNode = self.createNode(representedObject: representedObject, parent: containerNode) {
				updatedChildNodes += [newNode]
			}
		}

		updatedChildNodes = Node.nodesSortedAlphabeticallyWithFoldersAtEnd(updatedChildNodes)
		return updatedChildNodes
	}

	func createNode(representedObject: Any, parent: Node) -> Node? {
		
		if let feed = representedObject as? Feed {
			return createNode(feed: feed, parent: parent)
		}
		if let folder = representedObject as? Folder {
			return createNode(folder: folder, parent: parent)
		}
		return nil
	}
	
	func createNode(feed: Feed, parent: Node) -> Node {
		
		return Node(representedObject: feed, parent: parent)
	}
	
	func createNode(folder: Folder, parent: Node) -> Node {
		
		let node = Node(representedObject: folder, parent: parent)
		node.canHaveChildNodes = true
		return node
	}
	
	func nodeInArrayRepresentingObject(_ nodes: [Node], _ representedObject: AnyHashable) -> Node? {
		
		for oneNode in nodes {
			if oneNode.representedObject == representedObject {
				return oneNode
			}
		}
		return nil
	}
}
