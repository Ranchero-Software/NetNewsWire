//
//  Node.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/21/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Main thread only.

@MainActor public final class Node: Hashable {
	
	public weak var parent: Node?
	public let representedObject: AnyObject
	public var canHaveChildNodes = false
	public var isGroupItem = false
	public var childNodes = [Node]()
	public let uniqueID: Int
	private static var incrementingID = 0

	public var isRoot: Bool {
		if let _ = parent {
			return false
		}
		return true
	}
	
	public var numberOfChildNodes: Int {
		return childNodes.count
	}
	
	public var indexPath: IndexPath {
		if let parent = parent {
			let parentPath = parent.indexPath
			if let childIndex = parent.indexOfChild(self) {
				return parentPath.appending(childIndex)
			}
			preconditionFailure("A Node’s parent must contain it as a child.")
		}
		return IndexPath(index: 0) //root node
	}
	
	public var level: Int {
		if let parent = parent {
			return parent.level + 1
		}
		return 0
	}
	
	public var isLeaf: Bool {
		return numberOfChildNodes < 1
	}
	
	public init(representedObject: AnyObject, parent: Node?) {
		
		precondition(Thread.isMainThread)

		self.representedObject = representedObject
		self.parent = parent

		self.uniqueID = Node.incrementingID
		Node.incrementingID += 1
	}
	
	public class func genericRootNode() -> Node {
		
		let node = Node(representedObject: RootNodeRepresentedObject(), parent: nil)
		node.canHaveChildNodes = true
		return node
	}

	public func existingOrNewChildNode(with representedObject: AnyObject) -> Node {

		if let node = childNodeRepresentingObject(representedObject) {
			return node
		}
		return createChildNode(representedObject)
	}

	public func createChildNode(_ representedObject: AnyObject) -> Node {

		// Just creates — doesn’t add it.
		return Node(representedObject: representedObject, parent: self)
	}

	public func childAtIndex(_ index: Int) -> Node? {
		
		if index >= childNodes.count || index < 0 {
			return nil
		}
		return childNodes[index]
	}

	public func indexOfChild(_ node: Node) -> Int? {
		
		return childNodes.firstIndex{ (oneChildNode) -> Bool in
			oneChildNode === node
		}
	}
	
	public func childNodeRepresentingObject(_ obj: AnyObject) -> Node? {
		return findNodeRepresentingObject(obj, recursively: false)
	}

	public func descendantNodeRepresentingObject(_ obj: AnyObject) -> Node? {
		return findNodeRepresentingObject(obj, recursively: true)
	}

	public func descendantNode(where test: (Node) -> Bool) -> Node? {
		return findNode(where: test, recursively: true)
	}

	public func hasAncestor(in nodes: [Node]) -> Bool {

		for node in nodes {
			if node.isAncestor(of: self) {
				return true
			}
		}
		return false
	}

	public func isAncestor(of node: Node) -> Bool {

		if node == self {
			return false
		}

		var nomad = node
		while true {
			guard let parent = nomad.parent else {
				return false
			}
			if parent == self {
				return true
			}
			nomad = parent
		}
	}

	public class func nodesOrganizedByParent(_ nodes: [Node]) -> [Node: [Node]] {

		let nodesWithParents = nodes.filter { $0.parent != nil }
		return Dictionary(grouping: nodesWithParents, by: { $0.parent! })
	}

	public class func indexSetsGroupedByParent(_ nodes: [Node]) -> [Node: IndexSet] {

		let d = nodesOrganizedByParent(nodes)
		let indexSetDictionary = d.mapValues { (nodes) -> IndexSet in

			var indexSet = IndexSet()
			if nodes.isEmpty {
				return indexSet
			}

			let parent = nodes.first!.parent!
			for node in nodes {
				if let index = parent.indexOfChild(node) {
					indexSet.insert(index)
				}
			}

			return indexSet
		}

		return indexSetDictionary
	}

	// MARK: - Hashable

	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(uniqueID)
	}

	// MARK: - Equatable

	nonisolated public class func ==(lhs: Node, rhs: Node) -> Bool {
		return lhs === rhs
	}
}


public extension Array where Element == Node {

	@MainActor func representedObjects() -> [AnyObject] {

		return self.map{ $0.representedObject }
	}
}

private extension Node {

	func findNodeRepresentingObject(_ obj: AnyObject, recursively: Bool = false) -> Node? {

		for childNode in childNodes {
			if childNode.representedObject === obj {
				return childNode
			}
			if recursively, let foundNode = childNode.descendantNodeRepresentingObject(obj) {
				return foundNode
			}
		}

		return nil
	}

	func findNode(where test: (Node) -> Bool, recursively: Bool = false) -> Node? {

		for childNode in childNodes {
			if test(childNode) {
				return childNode
			}
			if recursively, let foundNode = childNode.findNode(where: test, recursively: recursively) {
				return foundNode
			}
		}

		return nil
	}

}
