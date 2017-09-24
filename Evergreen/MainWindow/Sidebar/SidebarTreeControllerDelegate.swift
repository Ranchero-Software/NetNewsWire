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
	
	func childNodesForRootNode(_ node: Node) -> [Node]? {
		
		// The child nodes are the top-level items of the local Account.
		// This will be expanded later to add synthetic feeds (All Unread, for instance).
		
		var updatedChildNodes = [Node]()
		
		let _ = AccountManager.shared.localAccount.visitChildren { (oneRepresentedObject) in
			
			if let existingNode = node.childNodeRepresentingObject(oneRepresentedObject as AnyObject) {
				// Reuse nodes.
				if !updatedChildNodes.contains(existingNode) {
					updatedChildNodes += [existingNode]
					return false
				}
			}
			
			if let newNode = createNode(representedObject: oneRepresentedObject as AnyObject, parent: node) {
				updatedChildNodes += [newNode]
			}
			
			return false
		}

		updatedChildNodes = Node.nodesSortedAlphabeticallyWithFoldersAtEnd(updatedChildNodes)
		return updatedChildNodes
	}
	
	func childNodesForFolderNode(_ node: Node) -> [Node]? {
		
		var updatedChildNodes = [Node]()
		let folder = node.representedObject as! Folder
		
		let _ = folder.visitChildren { (oneRepresentedObject) -> Bool in
			
			if let existingNode = node.childNodeRepresentingObject(oneRepresentedObject) {
				if !updatedChildNodes.contains(existingNode) {
					updatedChildNodes += [existingNode]
				}
				return false
			}
			
			if let newNode = self.createNode(representedObject: oneRepresentedObject, parent: node) {
				updatedChildNodes += [newNode]
			}
			
			return false
		}
		
		updatedChildNodes = Node.nodesSortedAlphabeticallyWithFoldersAtEnd(updatedChildNodes)
		return updatedChildNodes
	}
	
	func createNode(representedObject: AnyObject, parent: Node) -> Node? {
		
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
		
		let node = Node(representedObject: folder as AnyObject, parent: parent)
		node.canHaveChildNodes = true
		return node
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
