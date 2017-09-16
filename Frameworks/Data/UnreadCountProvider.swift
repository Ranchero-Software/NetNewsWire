//
//  UnreadCountProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 4/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public protocol UnreadCountProvider {

	var unreadCount: Int { get }
}

public func calculateUnreadCount<T: Collection>(_ children: T) -> Int {

	let updatedUnreadCount = children.reduce(0) { (result, oneChild) -> Int in
		if let oneUnreadCountProvider = oneChild as? UnreadCountProvider {
			return result + oneUnreadCountProvider.unreadCount
		}
		return result
	}

	return updatedUnreadCount
}

public extension UnreadCountProvider {
	
	public func postUnreadCountDidChangeNotification() {
		
		NotificationCenter.default.post(name: .UnreadCountDidChange, object: self, userInfo: [unreadCountKey: unreadCount])
	}
	
}
