//
//  CloudKitStatsViewModel.swift
//  Account
//
//  Created by Brent Simmons on 3/21/26.
//

import Foundation

public enum CloudKitStatsError: LocalizedError {

	case noiCloudAccount

	public var errorDescription: String? {
		switch self {
		case .noiCloudAccount:
			return NSLocalizedString("No iCloud account found.", comment: "CloudKit stats error")
		}
	}
}

public enum CloudKitStatsFetchStatus {

	case idle
	case fetching
	case completed
	case canceled
	case error(Error)

	public var isFetching: Bool {
		if case .fetching = self {
			return true
		}
		return false
	}

	public var isCompleted: Bool {
		if case .completed = self {
			return true
		}
		return false
	}

	public var fetchError: Error? {
		if case .error(let error) = self {
			return error
		}
		return nil
	}
}

@Observable @MainActor public final class CloudKitStatsViewModel {

	public var stats = CloudKitStats.empty {
		didSet {
			onChange?()
		}
	}

	public var fetchStatus = CloudKitStatsFetchStatus.idle {
		didSet {
			onChange?()
		}
	}

	// Called after each state change, so non-SwiftUI callers (AppKit) can update the UI.
	public var onChange: (() -> Void)?

	private var fetchTask: Task<Void, Never>?
	private var fetchSerialNumber = 0

	public var statsText: String {
		"""
		Status Records: \(stats.statusCount)
		  Starred: \(stats.starredStatusCount)
		  Unread: \(stats.unreadStatusCount)
		  Read: \(stats.readStatusCount)
		  Stale: \(stats.staleStatusCount)
		Article Content Records: \(stats.articleCount)
		  Starred: \(stats.starredArticleCount)
		  Unread: \(stats.unreadArticleCount)
		  Read: \(stats.readArticleCount)
		  Orphaned: \(stats.orphanedArticleCount)
		"""
	}

	public init() {
	}

	public func fetch() {
		guard let account = AccountManager.shared.iCloudAccount else {
			fetchStatus = .error(CloudKitStatsError.noiCloudAccount)
			return
		}

		fetchTask?.cancel()

		fetchStatus = .fetching
		stats = .empty

		fetchSerialNumber += 1
		let serialNumber = fetchSerialNumber

		fetchTask = Task {
			do {
				let stats = try await account.fetchCloudKitStats { partialStats in
					guard self.fetchSerialNumber == serialNumber else {
						return
					}
					self.stats = partialStats
				}
				guard self.fetchSerialNumber == serialNumber else {
					return
				}
				stats = stats
				fetchStatus = .completed
			} catch {
				guard self.fetchSerialNumber == serialNumber else {
					return
				}
				fetchStatus = .error(error)
			}
		}
	}

	public func cancelFetch() {
		fetchSerialNumber += 1
		fetchTask?.cancel()
		fetchTask = nil
		fetchStatus = .canceled
	}
}
