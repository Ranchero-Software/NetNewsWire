//
//  Node.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/21/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public final class Node: Equatable {
	
	public weak var parent: Node?
	public let representedObject: AnyObject
	public var canHaveChildNodes = false
	public var isGroupItem = false
	public var childNodes: [Node]?
	
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
		
		self.representedObject = representedObject
		self.parent = parent
	}
	
	public class func genericRootNode() -> Node {
		
		let node = Node(representedObject: TopLevelRepresentedObject(), parent: nil)
		node.canHaveChildNodes = true
		return node
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
}


public func ==(lhs: Node, rhs: Node) -> Bool {
	
	return lhs === rhs
}
