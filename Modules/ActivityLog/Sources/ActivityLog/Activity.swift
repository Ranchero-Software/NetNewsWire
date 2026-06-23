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

	public private(set) var state: ActivityState
	public private(set) var startDate: Date?
	public private(set) var endDate: Date?
	public private(set) var error: (any Error)?
	public private(set) var completionMessage: String?
	public private(set) var returnedFromCache = false

	/// Hide or show the duration in the UI.
	public var durationIsSignificant = true

	public init(id: Int, owner: ActivityOwner, kind: ActivityKind, detail: String? = nil) {
		self.id = id
		self.owner = owner
		self.kind = kind
		self.detail = detail
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

	func didComplete(_ message: String? = nil, returnedFromCache: Bool = false) {
		state = .completed
		endDate = Date()
		completionMessage = message
		self.returnedFromCache = returnedFromCache
	}

	func didFail(_ error: any Error) {
		state = .failed
		endDate = Date()
		self.error = error
	}

	/// The elapsed time from start to end, formatted for display — for example
	/// "0.45s", "12.3s", or "2m 15s". Nil when the duration isn't significant or
	/// the activity hasn't both started and ended.
	public var formattedDuration: String? {
		guard durationIsSignificant, let startDate, let endDate else {
			return nil
		}
		return Self.formattedDuration(endDate.timeIntervalSince(startDate))
	}

	static let posixLocale = Locale(identifier: "en_US_POSIX")

	static func formattedDuration(_ duration: TimeInterval) -> String {
		if duration < 10.0 {
			return String(format: "%.2fs", locale: posixLocale, duration)
		} else if duration < 60.0 {
			return String(format: "%.1fs", locale: posixLocale, duration)
		} else {
			let minutes = Int(duration) / 60
			let seconds = Int(duration) % 60
			return "\(minutes)m \(seconds)s"
		}
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
