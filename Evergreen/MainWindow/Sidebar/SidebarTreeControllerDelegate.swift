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
		if node.representedObject is Container {
			return childNodesForContainerNode(node)
		}

		return nil
	}	
}

private extension SidebarTreeControllerDelegate {
	
	func childNodesForRootNode(_ rootNode: Node) -> [Node]? {

		// The top-level nodes are pseudo-feeds (All Unread, Starred, etc.) and accounts.

		return pseudoFeedNodes(rootNode) + sortedAccountNodes(rootNode)
	}

	func pseudoFeedNodes(_ rootNode: Node) -> [Node] {

		// The appDelegate’s pseudoFeeds are already sorted properly.
		return appDelegate.pseudoFeeds.map { rootNode.createChildNode($0) }
	}

	func childNodesForContainerNode(_ containerNode: Node) -> [Node]? {

		let container = containerNode.representedObject as! Container

		var updatedChildNodes = [Node]()

		container.children.forEach { (representedObject) in

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
