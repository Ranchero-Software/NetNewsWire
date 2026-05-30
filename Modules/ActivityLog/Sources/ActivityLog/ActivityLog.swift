//
//  ActivityLog.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

import Foundation

public extension Notification.Name {

	static let activityDidChange = Notification.Name(rawValue: "ActivityDidChangeNotification")
}

public enum ActivityLogError: Error, Sendable {
	/// As determined by `removeStaleRunningActivities`.
	case timedOut
}

/// In-memory log of app activities (refreshes, downloads, status syncs).
/// Each activity moves through pending → running → completed/failed.
/// An `.activityDidChange` notification is posted onchange.
/// Lifecycle transitions can be called either with `(owner, kind)`
/// or with the id returned from `createActivity`.
@MainActor public final class ActivityLog {

	public static let shared = ActivityLog()

	/// Activities created but not yet started.
	public private(set) var pendingActivities = [Activity]()

	/// Activities currently in progress.
	public private(set) var runningActivities = [Activity]()

	/// Recently completed or failed activities.
	public private(set) var completedActivities = [Activity]()

	/// Maximum number of completed activities to retain.
	public let completedActivitiesLimit = 500

	/// A running activity older than this gets set to `completed` with
	/// `ActivityLogError.timedOut`.
	public let runningStaleAfterSeconds: TimeInterval = 15 * 60 // 15 minutes

	private var nextID = 0
	private var nextTaskNumber = 1

	public init() {
	}

	/// Returns a unique, incrementing task number for use in activity detail strings.
	public func nextTaskNumberString() -> String {
		let number = nextTaskNumber
		nextTaskNumber += 1
		return "#\(number)"
	}

	// MARK: - Creating Activities

	@discardableResult
	public func createActivity(owner: ActivityOwner, kind: ActivityKind, detail: String? = nil) -> Int {

		let id = nextID
		nextID += 1

		let activity = Activity(id: id, owner: owner, kind: kind, detail: detail)
		pendingActivities.append(activity)

		postDidChangeNotification()
		return id
	}

	// MARK: - Lifecycle by Kind

	public func didStart(_ owner: ActivityOwner, kind: ActivityKind) {

		guard let activity = findPendingActivity(owner: owner, kind: kind) else {
			return
		}

		activity.didStart()
		movePendingToRunning(activity)
		postDidChangeNotification()
	}

	/// Moves the activity from pending to running if it's still pending,
	/// without setting a start timestamp. Does nothing if already running.
	/// Used when an activity completes without ever truly starting.
	public func startIfNeeded(_ owner: ActivityOwner, kind: ActivityKind) {

		guard findRunningActivity(owner: owner, kind: kind) == nil else {
			return
		}
		guard let activity = findPendingActivity(owner: owner, kind: kind) else {
			return
		}

		activity.didStartWithoutTimestamp()
		movePendingToRunning(activity)
		postDidChangeNotification()
	}

	/// Completes the running activity matching `(owner, kind)`, promoting it from
	/// pending first if it was never explicitly started. Best-effort: does nothing
	/// if no activity matches. Assumes at most one active activity per
	/// `(owner, kind)` — for concurrent same-kind work, use the id-based API.
	public func didComplete(_ owner: ActivityOwner, kind: ActivityKind, message: String? = nil, durationIsSignificant: Bool = true) {

		guard let activity = ensureRunning(owner: owner, kind: kind) else {
			return
		}

		activity.durationIsSignificant = durationIsSignificant
		activity.didComplete(message)
		moveToCompleted(activity)
		postDidChangeNotification()
	}

	/// Fails the running activity matching `(owner, kind)`, promoting it from
	/// pending first if it was never explicitly started. Best-effort: does nothing
	/// if no activity matches. Assumes at most one active activity per
	/// `(owner, kind)` — for concurrent same-kind work, use the id-based API.
	public func didFail(_ owner: ActivityOwner, kind: ActivityKind, error: any Error) {

		guard let activity = ensureRunning(owner: owner, kind: kind) else {
			return
		}

		activity.durationIsSignificant = false
		activity.didFail(error)
		moveToCompleted(activity)
		postDidChangeNotification()
	}

	// MARK: - Lifecycle by ID

	public func didStart(id: Int) {

		guard let activity = findPendingActivity(id: id) else {
			assertionFailure("didStart: no pending activity with id \(id)")
			return
		}

		activity.didStart()
		movePendingToRunning(activity)
		postDidChangeNotification()
	}

	/// Completes the activity with `id`, promoting it from pending first if it was
	/// never explicitly started. A missing id is a programmer error (asserts).
	public func didComplete(id: Int, message: String? = nil, durationIsSignificant: Bool = true) {

		guard let activity = ensureRunning(id: id) else {
			assertionFailure("didComplete: no pending or running activity with id \(id)")
			return
		}

		activity.durationIsSignificant = durationIsSignificant
		activity.didComplete(message)
		moveToCompleted(activity)
		postDidChangeNotification()
	}

	/// Fails the activity with `id`, promoting it from pending first if it was
	/// never explicitly started. A missing id is a programmer error (asserts).
	public func didFail(id: Int, error: any Error) {

		guard let activity = ensureRunning(id: id) else {
			assertionFailure("didFail: no pending or running activity with id \(id)")
			return
		}

		activity.durationIsSignificant = false
		activity.didFail(error)
		moveToCompleted(activity)
		postDidChangeNotification()
	}

	// MARK: - Queries

	public func pendingActivities(for owner: ActivityOwner) -> [Activity] {
		pendingActivities.filter { $0.owner == owner }
	}

	public func runningActivities(for owner: ActivityOwner) -> [Activity] {
		runningActivities.filter { $0.owner == owner }
	}

	public func completedActivities(for owner: ActivityOwner) -> [Activity] {
		completedActivities.filter { $0.owner == owner }
	}
}

// MARK: - Private

private extension ActivityLog {

	/// Returns the running activity for `(owner, kind)`, promoting it from pending
	/// (without a start timestamp) if it was created but never started. Does not
	/// post a notification — the caller does.
	func ensureRunning(owner: ActivityOwner, kind: ActivityKind) -> Activity? {
		if let activity = findRunningActivity(owner: owner, kind: kind) {
			return activity
		}
		guard let activity = findPendingActivity(owner: owner, kind: kind) else {
			return nil
		}
		activity.didStartWithoutTimestamp()
		movePendingToRunning(activity)
		return activity
	}

	/// Returns the running activity for `id`, promoting it from pending (without a
	/// start timestamp) if it was created but never started. Does not post a
	/// notification — the caller does.
	func ensureRunning(id: Int) -> Activity? {
		if let activity = findRunningActivity(id: id) {
			return activity
		}
		guard let activity = findPendingActivity(id: id) else {
			return nil
		}
		activity.didStartWithoutTimestamp()
		movePendingToRunning(activity)
		return activity
	}

	func findPendingActivity(owner: ActivityOwner, kind: ActivityKind) -> Activity? {
		assert(pendingActivities.filter { $0.owner == owner && $0.kind == kind }.count <= 1, "Multiple pending activities for the same owner/kind; use the id-based API for concurrent same-kind work.")
		return pendingActivities.first { $0.owner == owner && $0.kind == kind }
	}

	func findPendingActivity(id: Int) -> Activity? {
		pendingActivities.first { $0.id == id }
	}

	func findRunningActivity(owner: ActivityOwner, kind: ActivityKind) -> Activity? {
		assert(runningActivities.filter { $0.owner == owner && $0.kind == kind }.count <= 1, "Multiple running activities for the same owner/kind; use the id-based API for concurrent same-kind work.")
		return runningActivities.first { $0.owner == owner && $0.kind == kind }
	}

	func findRunningActivity(id: Int) -> Activity? {
		runningActivities.first { $0.id == id }
	}

	func movePendingToRunning(_ activity: Activity) {
		pendingActivities.removeAll { $0 === activity }
		runningActivities.append(activity)
	}

	func moveToCompleted(_ activity: Activity) {
		runningActivities.removeAll { $0 === activity }
		completedActivities.append(activity)
		trimCompletedActivities()
	}

	func trimCompletedActivities() {
		if completedActivities.count > completedActivitiesLimit {
			completedActivities.removeFirst(completedActivities.count - completedActivitiesLimit)
		}
	}

	/// Move any running activity older than `runningStaleAfterSeconds` to
	/// completed with error `ActivityLogError.timedOut`.
	func removeStaleRunningActivities() {
		let cutoff = Date().addingTimeInterval(-runningStaleAfterSeconds)
		let stale = runningActivities.filter { activity in
			(activity.startDate ?? activity.creationDate) < cutoff
		}
		for activity in stale {
			activity.didFail(ActivityLogError.timedOut)
			moveToCompleted(activity)
		}
	}

	func postDidChangeNotification() {
		removeStaleRunningActivities()
		NotificationCenter.default.post(name: .activityDidChange, object: self)
	}
}
