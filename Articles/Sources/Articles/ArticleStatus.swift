//
//  ArticleStatus.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/1/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import os

/// Read and starred status for an Article.
///
/// These are uniqued — there is never more than one instance per articleID.
///
/// Its two Bool properties, `read` and `starred`, are both protected
/// by an internal lock, which makes `ArticleStatus` thread-safe.
public final class ArticleStatus: Hashable, @unchecked Sendable {

	public enum Key: String {
		case read = "read"
		case starred = "starred"
	}
	
	public let articleID: String
	public let dateArrived: Date

	// Sharing one lock for all instances is preferred to having one (or two)
	// locks per instance — that could means thousands of locks in memory.
	private static let lock = OSAllocatedUnfairLock()

	public var read: Bool {
		get {
			Self.lock.lock()
			defer {
				Self.lock.unlock()
			}

			return _read
		}
		set {
			Self.lock.lock()
			defer {
				Self.lock.unlock()
			}
			_read = newValue
		}
	}

	public var starred: Bool {
		get {
			Self.lock.lock()
			defer {
				Self.lock.unlock()
			}

			return _starred
		}
		set {
			Self.lock.lock()
			defer {
				Self.lock.unlock()
			}
			_starred = newValue
		}
	}

	private var _read = false
	private var _starred = false

	public init(articleID: String, read: Bool, starred: Bool, dateArrived: Date) {
		self.articleID = articleID
		self.dateArrived = dateArrived
		self._read = read
		self._starred = starred
	}

	public convenience init(articleID: String, read: Bool, dateArrived: Date) {
		self.init(articleID: articleID, read: read, starred: false, dateArrived: dateArrived)
	}

	public func boolStatus(forKey key: ArticleStatus.Key) -> Bool {
		switch key {
		case .read:
			return read
		case .starred:
			return starred
		}
	}
	
	public func setBoolStatus(_ status: Bool, forKey key: ArticleStatus.Key) {
		switch key {
		case .read:
			read = status
		case .starred:
			starred = status
		}
	}

	// MARK: - Hashable

	public func hash(into hasher: inout Hasher) {
		hasher.combine(articleID)
	}

	// MARK: - Equatable

	public static func ==(lhs: ArticleStatus, rhs: ArticleStatus) -> Bool {
		return lhs.articleID == rhs.articleID && lhs.dateArrived == rhs.dateArrived && lhs.read == rhs.read && lhs.starred == rhs.starred
	}
}

public extension Set where Element == ArticleStatus {
	
	func articleIDs() -> Set<String> {
		return Set<String>(map { $0.articleID })
	}
}

public extension Array where Element == ArticleStatus {
	
	func articleIDs() -> [String] {		
		return map { $0.articleID }
	}
}
