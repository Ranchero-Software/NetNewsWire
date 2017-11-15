//
//  Log.swift
//  RSCore
//
//  Created by Brent Simmons on 11/14/17.
//  Copyright © 2017 Ranchero Software, LLC. All rights reserved.
//

import Foundation

public class Log {

	public var logItems = [LogItem]()

	public init() {
		// Satisfy compiler
	}

	public func add(_ logItem: LogItem) {

		logItems += [logItem]
	}
}
