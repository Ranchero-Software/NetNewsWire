//
//  CloudKitSyncMessage.swift
//  Account
//
//  Created by Brent Simmons on 4/5/26.
//

import Foundation
import ActivityLog

/// Logs one page or batch of a looping CloudKit operation as its own activity.
///
/// This is for work already done by the time it’s logged
/// — `durationIsSignificant` is false.
@MainActor func logCloudKitSubActivity(owner: ActivityOwner, kind: ActivityKind, message: String) {
	let detail = ActivityLog.shared.nextTaskNumberString()
	ActivityLog.shared.logCompletedActivity(owner: owner, kind: kind, detail: detail, message: message)
}

/// Wraps one page or batch of a looping CloudKit operation in its own activity,
/// timing `work` so the entry shows a real duration. Use this when the caller owns
/// the fetch boundary — start is logged before the work begins. Use the non-timed
/// overload above for work already finished by the time it’s logged.
@MainActor func logCloudKitSubActivity<T>(owner: ActivityOwner, kind: ActivityKind, message: @escaping (T) -> String, _ work: () async throws -> T) async rethrows -> T {
	let detail = ActivityLog.shared.nextTaskNumberString()
	return try await ActivityLog.shared.logActivity(owner: owner, kind: kind, detail: detail, successMessage: { message($0) }, work)
}

/// Returns a human-readable summary of changed/deleted record counts
/// for use in activity log completion messages.
func cloudKitSyncMessage(changed: Int, deleted: Int) -> String {
	if changed == 0 && deleted == 0 {
		return "No changes"
	}
	var parts = [String]()
	if changed > 0 {
		parts.append("\(changed) changed")
	}
	if deleted > 0 {
		parts.append("\(deleted) deleted")
	}
	return parts.joined(separator: ", ")
}
