//
//  AuthorCache.swift
//  Articles
//
//  Created by Brent Simmons on 4/28/26.
//

import Foundation
import os
import RSCore

/// Caches `Author` values by `authorID` so articles by the same author share
/// the same `Author` value (and underlying String storage). Cleared on `.lowMemory`.
public final class AuthorCache: Sendable {

	public static let shared = AuthorCache()

	private let cache = OSAllocatedUnfairLock<[String: Author]>(initialState: [:])

	init() {
		if !Platform.isRunningUnitTests {
			NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		}
	}

	public func add(_ authors: Set<Author>) -> Set<Author> {
		cache.withLock { dict in
			Set(authors.map { author in
				if let existing = dict[author.authorID] {
					return existing
				}
				dict[author.authorID] = author
				return author
			})
		}
	}

	public func clear() {
		cache.withLock { $0.removeAll() }
	}

	@objc func handleLowMemory(_ notification: Notification) {
		clear()
	}
}

#if DEBUG
extension AuthorCache {

	/// For tests only.
	func count() -> Int {
		cache.withLock { $0.count }
	}
}
#endif
