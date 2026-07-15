//
//  MinifluxVersion.swift
//  Account
//
//  Created by Dave Marquard on 7/8/26.
//  Copyright © 2026 Ranchero Software, LLC. All rights reserved.
//

import Foundation

// GET /v1/version → {"version":"2.3.2","commit":"...","build_date":"...",...}
struct MinifluxVersionResponse: Decodable, Sendable {
	let version: String
}

/// A dotted numeric version, e.g. "2.3.2". Tolerates a non-numeric suffix on the last
/// component, e.g. "2.3.2-dev", but fails to parse a wholly non-numeric component.
struct MinifluxVersion: Comparable, Sendable {

	private let components: [Int]

	init(_ components: Int...) {
		self.components = components
	}

	init?(string: String) {
		let parts = string.split(separator: ".")
		guard !parts.isEmpty else {
			return nil
		}

		var parsedComponents = [Int]()
		for part in parts {
			let digits = part.prefix { $0.isNumber }
			guard let value = Int(digits) else {
				return nil
			}
			parsedComponents.append(value)
		}

		components = parsedComponents
	}

	static func == (lhs: MinifluxVersion, rhs: MinifluxVersion) -> Bool {
		lhs.compare(rhs) == .orderedSame
	}

	static func < (lhs: MinifluxVersion, rhs: MinifluxVersion) -> Bool {
		lhs.compare(rhs) == .orderedAscending
	}

	private func compare(_ other: MinifluxVersion) -> ComparisonResult {
		let count = max(components.count, other.components.count)
		for i in 0..<count {
			let lhsValue = i < components.count ? components[i] : 0
			let rhsValue = i < other.components.count ? other.components[i] : 0
			if lhsValue != rhsValue {
				return lhsValue < rhsValue ? .orderedAscending : .orderedDescending
			}
		}
		return .orderedSame
	}
}
