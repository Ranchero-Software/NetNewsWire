//
//  Inkwell.swift
//  Account
//
//  Created by Manton Reece on 3/11/26.
//

import Foundation
import os.log

struct Inkwell {
	// Convention with this logger is to put "Inkwell: " at the beginning of each message.
	static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "Inkwell")
}
