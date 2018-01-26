//
//  Node.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/21/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// Main thread only.

public final class Node: Hashable {
	
	public weak var parent: Node?
	public let representedObject: AnyObject
	public var canHaveChildNodes = false
	public var isGroupItem = false
	public var childNodes: [Node]?
	public let hashValue: Int
	private static var incrementingID = 0

	public var isRoot: Bool {
		get {
			if let _ = parent {
				return false
			}
			return true
		}
	}
	
	public var numberOfChildNodes: Int {
		get {
			return childNodes?.count ?? 0
		}
	}
	
	public var indexPath: IndexPath {
		get {
			if let parent = parent {
				let parentPath = parent.indexPath
				if let childIndex = parent.indexOfChild(self) {
					return parentPath.appending(childIndex)
				}
				preconditionFailure("A Node’s parent must contain it as a child.")
			}
			return IndexPath(index: 0) //root node
		}
	}
	
	public var level: Int {
		get {
			if let parent = parent {
				return parent.level + 1
			}
			return 0
		}
	}
	
	public var isLeaf: Bool {
		get {
			return numberOfChildNodes < 1
		}
	}

	public init(representedObject: AnyObject, parent: Node?) {

		precondition(Thread.isMainThread)

		self.representedObject = representedObject
		self.parent = parent

		self.hashValue = Node.incrementingID
		Node.incrementingID += 1
	}
	
	public class func genericRootNode() -> Node {
		
		let node = Node(representedObject: TopLevelRepresentedObject(), parent: nil)
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
		
		guard let childNodes = childNodes else {
			return nil
		}
		if index >= childNodes.count || index < 0 {
			return nil
		}
		return childNodes[index]
	}

	public func indexOfChild(_ node: Node) -> Int? {
		
		return childNodes?.index{ (oneChildNode) -> Bool in
			oneChildNode === node
		}
	}
	
	public func childNodeRepresentingObject(_ obj: AnyObject) -> Node? {
		
		guard let childNodes = childNodes else {
			return nil
		}
		
		for oneNode in childNodes {
			if oneNode.representedObject === obj {
				return oneNode
			}
		}
		return nil
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
}


public func ==(lhs: Node, rhs: Node) -> Bool {
	
	return lhs === rhs
}

public extension Array where Element == Node {

	public func representedObjects() -> [AnyObject] {

		return self.map{ $0.representedObject }
	}
}
