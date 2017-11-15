//
//  Log.swift
//  RSCore
//
//  Created by Brent Simmons on 11/14/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public extension Notification.Name {

	public static let LogDidAddItem = NSNotification.Name("LogDidAddItem")
}

public class Log {

	public var logItems = [LogItem]()
	public static let logItemKey = "logItem" // userInfo key
	private let lock = NSLock()

	public init() {
		// Satisfy compiler
	}

	public func add(_ logItem: LogItem) {

		lock.lock()
		logItems += [logItem]
		lock.unlock()

		NotificationCenter.default.post(name: .LogDidAddItem, object: self, userInfo: [Log.logItemKey: logItem])
	}
}
