//
//  CloudKitSyncMessage.swift
//  Account
//
//  Created by Brent Simmons on 4/5/26.
//

import Foundation

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
