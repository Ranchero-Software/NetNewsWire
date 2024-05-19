//
//  NodeTests.swift
//  
//
//  Created by Brent Simmons on 5/18/24.
//

import XCTest
import Tree

final class NodeTests: XCTestCase {

	private final class TestClass {}

	@MainActor func testNodeIsRootNode() {

		var node = Node(representedObject: TestClass(), parent: nil)
		XCTAssertTrue(node.isRoot)

		node = Node.genericRootNode()
		XCTAssertTrue(node.isRoot)
	}
}
