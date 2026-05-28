//
//  Activity.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

import Foundation

/// A single activity tracked in ActivityLog.
@MainActor public final class Activity {

	public let id: Int
	public let owner: ActivityOwner
	public let kind: ActivityKind
	public let detail: String?
	public let creationDate: Date

	public private(set) var state: ActivityState
	public private(set) var startDate: Date?
	public private(set) var endDate: Date?
	public private(set) var error: (any Error)?
	public private(set) var completionMessage: String?

	/// Hide or show the duration in the UI.
	public var durationIsSignificant = true

	public init(id: Int, owner: ActivityOwner, kind: ActivityKind, detail: String? = nil) {
		self.id = id
		self.owner = owner
		self.kind = kind
		self.detail = detail
		self.creationDate = Date()
		self.state = .pending
	}

	func didStart() {
		state = .running
		startDate = Date()
	}

	/// Transition from pending to running without setting startDate.
	/// Used when an activity completes without ever truly starting
	/// (e.g. cached or skipped downloads).
	func didStartWithoutTimestamp() {
		state = .running
	}

	func didComplete(_ message: String? = nil) {
		state = .completed
		endDate = Date()
		completionMessage = message
	}

	func didFail(_ error: any Error) {
		state = .failed
		endDate = Date()
		self.error = error
	}
}

extension Activity: Hashable {

	nonisolated public func hash(into hasher: inout Hasher) {
		hasher.combine(id)
	}

	nonisolated public static func ==(lhs: Activity, rhs: Activity) -> Bool {
		lhs === rhs
	}
}
