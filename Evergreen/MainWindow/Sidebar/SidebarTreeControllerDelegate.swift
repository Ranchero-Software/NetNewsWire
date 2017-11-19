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
		if node.representedObject is Account {
			return childNodesForAccount(node)
		}
		
		return nil
	}	
}

private extension SidebarTreeControllerDelegate {
	
	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {

		// The top-level nodes are pseudo-feeds (All Unread, Starred, etc.) and accounts.
		// TODO: pseudo-feeds

		return sortedAccountNodes(rootNode)
	}

	func childNodesForAccount(_ accountNode: Node) -> [Node]? {

		let account = accountNode.representedObject as! Account
		return childNodesForContainerNode(accountNode, account.children)
	}

	func childNodesForFolderNode(_ folderNode: Node) -> [Node]? {

		let folder = folderNode.representedObject as! Folder
		return childNodesForContainerNode(folderNode, folder.children)
	}

	func childNodesForContainerNode(_ containerNode: Node, _ children: [AnyObject]) -> [Node]? {

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

		return updatedChildNodes.sortedAlphabeticallyWithFoldersAtEnd()
	}

	func createNode(representedObject: Any, parent: Node) -> Node? {
		
		if let feed = representedObject as? Feed {
			return createNode(feed: feed, parent: parent)
		}
		if let folder = representedObject as? Folder {
			return createNode(folder: folder, parent: parent)
		}
		if let account = representedObject as? Account {
			return createNode(account: account, parent: parent)
		}

		return nil
	}
	
	func createNode(feed: Feed, parent: Node) -> Node {

		return parent.createChildNode(feed)
	}
	
	func createNode(folder: Folder, parent: Node) -> Node {

		let node = parent.createChildNode(folder)
		node.canHaveChildNodes = true
		return node
	}

	func createNode(account: Account, parent: Node) -> Node {

		let node = parent.createChildNode(account)
		node.canHaveChildNodes = true
		node.isGroupItem = true
		return node
	}

	func sortedAccountNodes(_ parent: Node) -> [Node] {

		let nodes = AccountManager.shared.accounts.map { createNode(account: $0, parent: parent) }
		return nodes.sortedAlphabetically()
	}

	func nodeInArrayRepresentingObject(_ nodes: [Node], _ representedObject: AnyObject) -> Node? {
		
		for oneNode in nodes {
			if oneNode.representedObject === representedObject {
				return oneNode
			}
		}
		return nil
	}
}
