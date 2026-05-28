//
//  HTMLMetadataNotification.swift
//  HTMLMetadata
//
//  Created by Brent Simmons on 4/6/26.
//

import Foundation

public extension Notification.Name {

	/// Posted when HTMLMetadata is cached. Posted on any thread.
	nonisolated static let htmlMetadataAvailable = Notification.Name("htmlMetadataAvailable")
}

public struct HTMLMetadataUserInfoKey {

	public static let record = "htmlMetadataRecord" // HTMLMetadataRecord value
	public static let url = "url" // String value
}
