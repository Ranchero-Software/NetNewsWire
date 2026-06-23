//
//  ActivityState.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

/// Lifecycle.
public enum ActivityState: Sendable {

	case pending
	case running
	case completed
	case failed
}
