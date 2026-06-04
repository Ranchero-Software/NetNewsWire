//
//  Comparing.swift
//  RSCore
//
//  Created by Brent Simmons on 6/3/26.
//

import Foundation

// Helpers for `Array.sort` closures.

/// Compare using `localizedCaseInsensitiveCompare`.
public func compareStrings(_ lhs: String, _ rhs: String, ascending: Bool) -> Bool {
	let result = lhs.localizedCaseInsensitiveCompare(rhs)
	return ascending ? result == .orderedAscending : result == .orderedDescending
}

public func compareValues<T: Comparable>(_ lhs: T, _ rhs: T, ascending: Bool) -> Bool {
	ascending ? lhs < rhs : lhs > rhs
}

/// Compare optional `Comparable` values. Nil sorts before non-nil when ascending.
public func compareOptionals<T: Comparable>(_ lhs: T?, _ rhs: T?, ascending: Bool) -> Bool {
	switch (lhs, rhs) {
	case (nil, nil):
		return false
	case (nil, _):
		return ascending
	case (_, nil):
		return !ascending
	case let (l?, r?):
		return ascending ? l < r : l > r
	}
}

// Direction-free comparisons returning `ComparisonResult`. Use when chaining a
// tiebreaker — apply the ascending flag once at the end.

public func compareValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
	if lhs < rhs {
		return .orderedAscending
	}
	if lhs > rhs {
		return .orderedDescending
	}
	return .orderedSame
}

/// Compare optional `Comparable` values. Nil sorts before non-nil.
public func compareOptionals<T: Comparable>(_ lhs: T?, _ rhs: T?) -> ComparisonResult {
	switch (lhs, rhs) {
	case (nil, nil):
		return .orderedSame
	case (nil, _):
		return .orderedAscending
	case (_, nil):
		return .orderedDescending
	case let (l?, r?):
		return compareValues(l, r)
	}
}
