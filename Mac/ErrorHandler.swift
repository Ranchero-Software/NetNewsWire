//
//  ErrorHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import os.log

// asserts that OSLog is a sendable type
// @preconcurrency import os.log _should_ resolve the warning in this scenario, but does
// not due to a bug (in Swift 5.10)
#if swift(>=6.0)
	#warning("Reevaluate whether this Sendable decoration is still needed for OSLog.")
#endif
extension OSLog: @unchecked Sendable { }

struct ErrorHandler {

	private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Account")

	@MainActor public static func present(_ error: Error) {
		NSApplication.shared.presentError(error)
	}
	
	public static func log(_ error: Error) {
		os_log(.error, log: log, "%@", error.localizedDescription)
	}
	
}
