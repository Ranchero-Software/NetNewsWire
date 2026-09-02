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

public enum CloudKitCleanUpStatus {

	case idle
	case cleaning(CloudKitCleanUpProgress)
	case completed(CloudKitCleanUpProgress)
	case canceled(CloudKitCleanUpProgress)
	case error(Error)

	public var isCleaning: Bool {
		if case .cleaning = self {
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

	public var isCanceled: Bool {
		if case .canceled = self {
			return true
		}
		return false
	}

	public var progress: CloudKitCleanUpProgress? {
		switch self {
		case .cleaning(let progress), .completed(let progress), .canceled(let progress):
			return progress
		case .idle, .error:
			return nil
		}
	}

	public var isActive: Bool {
		switch self {
		case .idle:
			return false
		case .cleaning, .completed, .canceled, .error:
			return true
		}
	}

	public var cleanUpError: Error? {
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

	public var cleanUpStatus = CloudKitCleanUpStatus.idle {
		didSet {
			onChange?()
		}
	}

	// Called after each state change, so non-SwiftUI callers (AppKit) can update the UI.
	public var onChange: (() -> Void)?

	public private(set) var cleanUpPlanIsStale = false

	private var fetchTask: Task<Void, Never>?
	private var fetchSerialNumber = 0
	private var cleanUpTask: Task<Void, Never>?

	public var cleanUpPlan: CloudKitCleanUpPlan {
		let syncUnreadContent = AccountManager.shared.syncArticleContentForUnreadArticles
		return stats.cleanUpPlan(syncUnreadContent: syncUnreadContent)
	}

	public var canCleanUp: Bool {
		fetchStatus.isCompleted && (cleanUpPlanIsStale || !cleanUpPlan.isEmpty) && !cleanUpStatus.isCleaning
	}

	public var statsText: String {
		"""
		Status Records: \(formattedCount(stats.statusCount))
		  Starred: \(formattedCount(stats.starredStatusCount))
		  Unread: \(formattedCount(stats.unreadStatusCount))
		  Read: \(formattedCount(stats.readStatusCount))
		Article Content Records: \(formattedCount(stats.articleCount))
		  Starred: \(formattedCount(stats.starredArticleCount))
		  Unread: \(formattedCount(stats.unreadArticleCount))
		  Read: \(formattedCount(stats.readArticleCount))
		"""
	}

	public var cleanUpStatsText: String {
		guard let progress = cleanUpStatus.progress else {
			return ""
		}

		var lines = [String]()
		if progress.readContentDeleted > 0 {
			lines.append("Read Content Deleted: \(formattedCount(progress.readContentDeleted))")
		}
		if progress.unreadContentDeleted > 0 {
			lines.append("Unread Content Deleted: \(formattedCount(progress.unreadContentDeleted))")
		}
		return lines.joined(separator: "\n")
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
		cleanUpStatus = .idle
		cleanUpPlanIsStale = false
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
				self.stats = stats
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

	public func cancelCleanUp() {
		cleanUpTask?.cancel()
		cleanUpTask = nil
		cleanUpPlanIsStale = true
		if let progress = cleanUpStatus.progress {
			cleanUpStatus = .canceled(progress)
		}
	}

	public func cleanUp() {
		guard let account = AccountManager.shared.iCloudAccount else {
			cleanUpStatus = .error(CloudKitStatsError.noiCloudAccount)
			return
		}

		cleanUpStatus = .cleaning(CloudKitCleanUpProgress(phase: .deletingReadContent, staleStatusDeleted: 0, readContentDeleted: 0, unreadContentDeleted: 0))

		cleanUpTask = Task {
			do {
				try await account.cleanUpCloudKit { progress in
					self.cleanUpStatus = .cleaning(progress)
					if progress.phase == .completed {
						self.cleanUpPlanIsStale = true
						self.cleanUpStatus = .completed(progress)
					}
				}
			} catch {
				if !cleanUpStatus.isCanceled {
					cleanUpPlanIsStale = true
					cleanUpStatus = .error(error)
				}
			}
		}
	}

}

private extension CloudKitStatsViewModel {

	func formattedCount(_ count: Int) -> String {
		NumberFormatter.localizedString(from: NSNumber(value: count), number: .decimal)
	}
}
