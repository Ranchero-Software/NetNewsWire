//
//  OPMLRepresentable.swift
//  DataModel
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol OPMLRepresentable {

	@MainActor func OPMLString(indentLevel: Int, allowCustomAttributes: Bool) -> String
}

public extension OPMLRepresentable {

	@MainActor func OPMLString(indentLevel: Int) -> String {
		return OPMLString(indentLevel: indentLevel, allowCustomAttributes: false)
	}
}
