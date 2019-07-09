//
//  UnreadCountProtocol.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 4/8/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Notification.Name {

	static let UnreadCountDidChange = Notification.Name(rawValue: "UnreadCountDidChange")
}

public protocol UnreadCountProvider {

	var unreadCount: Int { get }

	func postUnreadCountDidChangeNotification()
	func calculateUnreadCount<T: Collection>(_ children: T) -> Int
}


public extension UnreadCountProvider {
	
	func postUnreadCountDidChangeNotification() {
		NotificationCenter.default.post(name: .UnreadCountDidChange, object: self, userInfo: nil)
	}

	func calculateUnreadCount<T: Collection>(_ children: T) -> Int {
		let updatedUnreadCount = children.reduce(0) { (result, oneChild) -> Int in
			if let oneUnreadCountProvider = oneChild as? UnreadCountProvider {
				return result + oneUnreadCountProvider.unreadCount
			}
			return result
		}

		return updatedUnreadCount
	}
}


