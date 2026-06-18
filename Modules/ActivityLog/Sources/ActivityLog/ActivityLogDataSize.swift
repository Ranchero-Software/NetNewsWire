//
//  ActivityLogDataSize.swift
//  ActivityLog
//
//  Created by Brent Simmons on 6/18/26.
//

import Foundation

public extension ActivityLog {

	/// Formats a download size for an activity message — for example "39 kB".
	nonisolated static func dataSizeMessage(_ data: Data) -> String {
		Int64(data.count).formatted(.byteCount(style: .file))
	}
}
