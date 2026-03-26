//
//  CloudKitStats.swift
//  Account
//
//  Created by Brent Simmons on 3/20/26.
//

import Foundation

public typealias CloudKitStatsProgressHandler = @MainActor @Sendable (CloudKitStats) -> Void

public struct CloudKitStats: Sendable {

	public static let empty = CloudKitStats(statusCount: 0, starredStatusCount: 0, unreadStatusCount: 0, readStatusCount: 0, staleStatusCount: 0, articleCount: 0, starredArticleCount: 0, unreadArticleCount: 0, readArticleCount: 0)

	public let statusCount: Int
	public let starredStatusCount: Int
	public let unreadStatusCount: Int
	public let readStatusCount: Int
	public let staleStatusCount: Int

	public let articleCount: Int
	public let starredArticleCount: Int
	public let unreadArticleCount: Int
	public let readArticleCount: Int

	public func cleanUpPlan(syncUnreadContent: Bool) -> CloudKitCleanUpPlan {
		CloudKitCleanUpPlan(
			staleStatusCount: staleStatusCount,
			readContentCount: readArticleCount,
			unreadContentCount: syncUnreadContent ? 0 : unreadArticleCount
		)
	}
}

public struct CloudKitCleanUpPlan: Sendable {

	public let staleStatusCount: Int
	public let readContentCount: Int
	public let unreadContentCount: Int

	public var totalCount: Int {
		readContentCount + unreadContentCount
	}

	public var isEmpty: Bool {
		totalCount == 0
	}
}

public enum CloudKitCleanUpPhase: Sendable {

	case deletingStaleStatus
	case deletingReadContent
	case deletingUnreadContent
	case completed
}

public struct CloudKitCleanUpProgress: Sendable {

	public let phase: CloudKitCleanUpPhase
	public let staleStatusDeleted: Int
	public let readContentDeleted: Int
	public let unreadContentDeleted: Int

	public var totalDeleted: Int {
		readContentDeleted + unreadContentDeleted
	}
}
