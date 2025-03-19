//
//  CustomSmartFeedTests.swift
//  NetNewsWire
//
//  Created by Mateusz on 19/03/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Testing
@testable import NetNewsWire

@Test func testCustomSmartFeed() async throws {
	let expression1: CustomSmartFeedExpression = (
		field: CustomSmartFeedField.text(.title),
		constraint: CustomSmartFeedConstraint.textHas,
		value: CustomSmartFeedValue.text("title")
	)
	let expression2: CustomSmartFeedExpression = (
		field: CustomSmartFeedField.date(.datePublished),
		constraint: CustomSmartFeedConstraint.dateExact,
		value: CustomSmartFeedValue.date(.init(timeIntervalSince1970: 1234567890))
	)
	
	let expressions = [expression1, expression2]
	let query = expressions.query(conjunction: true)
	let parameters = expressions.parameters
	
	#expect(query == "(title LIKE '%' || ? || '%') AND (datePublished = ?)")
	#expect(parameters == ["title", "1234567890"])
	#expect(query.count(where: { $0 == "?" }) == parameters.count)
}
