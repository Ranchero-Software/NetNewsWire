//
//  UnreadCountProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol UnreadCountProvider {

	var unreadCount: Int {get}

	func updateUnreadCount()
}

public func calculateUnreadCount<T: Collection>(_ children: T) -> Int {

	var updatedUnreadCount = 0

	children.forEach { (oneChild) in
		if let oneUnreadCountProvider = oneChild as? UnreadCountProvider {
			updatedUnreadCount += oneUnreadCountProvider.unreadCount
		}
	}

	return updatedUnreadCount
}

public extension UnreadCountProvider {
	
	public func postUnreadCountDidChangeNotification() {
		
		NotificationCenter.default.post(name: .UnreadCountDidChange, object: self, userInfo: [unreadCountKey: unreadCount])
	}
	
}
