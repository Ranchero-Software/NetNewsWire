//
//  NewsBlur.swift
//  Account
//
//  Created by Brent Simmons on 10/2/25.
//

import Foundation
import os.log

public struct NewsBlur {
	// Convention with this logger is to put "NewsBlur: " at the beginning of each message.
	public static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "NewsBlur")
}
