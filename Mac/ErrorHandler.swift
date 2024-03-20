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

struct ErrorHandler {

	private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Account")

	@MainActor public static func present(_ error: Error) {
		NSApplication.shared.presentError(error)
	}
	
	public static func log(_ error: Error) {
		os_log(.error, log: log, "%@", error.localizedDescription)
	}
	
}
