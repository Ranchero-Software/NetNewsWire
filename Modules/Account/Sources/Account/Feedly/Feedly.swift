//
//  Feedly.swift
//  Account
//
//  Created by Brent Simmons on 10/2/25.
//

import Foundation
import os.log

struct Feedly: Sendable {
	// Convention with this logger is to put "Feedly: " at the beginning of each message.
	static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Feedly")
}
