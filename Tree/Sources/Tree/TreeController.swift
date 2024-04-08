//
//  TreeController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 5/29/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol TreeControllerDelegate: AnyObject {
	
	@MainActor func treeController(treeController: TreeController, childNodesFor: Node) -> [Node]?
}

public typealias NodeVisitBlock = (_ : Node) -> Void

@MainActor public final class TreeController {

	private weak var delegate: TreeControllerDelegate?
	public let rootNode: Node

	public init(delegate: TreeControllerDelegate, rootNode: Node) {
		
		self.delegate = delegate
		self.rootNode = rootNode
		rebuild()
	}

	public convenience init(delegate: TreeControllerDelegate) {
		
		self.init(delegate: delegate, rootNode: Node.genericRootNode())
	}
	
	@discardableResult
	public func rebuild() -> Bool {

		// Rebuild and re-sort. Return true if any changes in the entire tree.
		
		return rebuildChildNodes(node: rootNode)
	}
	
	public func visitNodes(_ visitBlock: NodeVisitBlock) {
		
		visitNode(rootNode, visitBlock)
	}
	
	public func nodeInArrayRepresentingObject(nodes: [Node], representedObject: AnyObject, recurse: Bool = false) -> Node? {
		
		for oneNode in nodes {

			if oneNode.representedObject === representedObject {
				return oneNode
			}

			if recurse, oneNode.canHaveChildNodes {
				if let foundNode = nodeInArrayRepresentingObject(nodes: oneNode.childNodes, representedObject: representedObject, recurse: recurse) {
					return foundNode
				}

			}
		}
		return nil
	}

	public func nodeInTreeRepresentingObject(_ representedObject: AnyObject) -> Node? {

		return nodeInArrayRepresentingObject(nodes: [rootNode], representedObject: representedObject, recurse: true)
	}

	public func normalizedSelectedNodes(_ nodes: [Node]) -> [Node] {

		// An array of nodes might include a leaf node and its parent. Remove the leaf node.

		var normalizedNodes = [Node]()

		for node in nodes {
			if !node.hasAncestor(in: nodes) {
				normalizedNodes += [node]
			}
		}

		return normalizedNodes
	}
}

private extension TreeController {
	
	func visitNode(_ node: Node, _ visitBlock: NodeVisitBlock) {
		
		visitBlock(node)
		
		for oneChildNode in node.childNodes {
			visitNode(oneChildNode, visitBlock)
		}
	}
	
	func nodeArraysAreEqual(_ nodeArray1: [Node]?, _ nodeArray2: [Node]?) -> Bool {
		
		if nodeArray1 == nil && nodeArray2 == nil {
			return true
		}
		if nodeArray1 != nil && nodeArray2 == nil {
			return false
		}
		if nodeArray1 == nil && nodeArray2 != nil {
			return false
		}
		
		return nodeArray1! == nodeArray2!
	}
	
	func rebuildChildNodes(node: Node) -> Bool {
		
		if !node.canHaveChildNodes {
			return false
		}
		
		let childNodes = delegate?.treeController(treeController: self, childNodesFor: node) ?? [Node]()
		
		var childNodesDidChange = !nodeArraysAreEqual(childNodes, node.childNodes)
		if childNodesDidChange {
			node.childNodes = childNodes
		}
		
		for oneChildNode in childNodes {
			if rebuildChildNodes(node: oneChildNode) {
				childNodesDidChange = true
			}
		}

		return childNodesDidChange
	}
}
