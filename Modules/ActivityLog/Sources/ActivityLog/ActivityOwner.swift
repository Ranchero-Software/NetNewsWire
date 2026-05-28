//
//  ActivityOwner.swift
//  ActivityLog
//
//  Created by Brent Simmons on 4/4/26.
//

public enum ActivityOwner: Sendable, Hashable {

	case app
	case account(String) // accountID
	case feedFinder
	case feedImageDownloader
	case htmlMetadataDownloader
}
