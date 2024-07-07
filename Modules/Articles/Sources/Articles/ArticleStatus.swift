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
/// These are uniqued — there is never more than one instance per articleID per account.
///
/// Its two mutable Bool properties, `read` and `starred`, are each protected
/// by an OSAllocatedUnfairLock, which makes `ArticleStatus` Sendable.
public final class ArticleStatus: Hashable, Sendable {

	public enum Key: String, Sendable {
		case read = "read"
		case starred = "starred"
	}
	
	public let articleID: String
	public let dateArrived: Date

	private let _read: OSAllocatedUnfairLock<Bool>
	private let _starred: OSAllocatedUnfairLock<Bool>

	public var read: Bool {
		get {
			_read.withLock { $0 }
		}
		set {
			_read.withLock { $0 = newValue }
		}
	}

	public var starred: Bool {
		get {
			_starred.withLock { $0 }
		}
		set {
			_starred.withLock { $0 = newValue }
		}
	}

	public init(articleID: String, read: Bool, starred: Bool, dateArrived: Date) {
		self.articleID = articleID
		self.dateArrived = dateArrived
		self._read = OSAllocatedUnfairLock(initialState: read)
		self._starred = OSAllocatedUnfairLock(initialState: starred)
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
