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

nonisolated struct ErrorHandler: Sendable {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ErrorHandler")

	@Sendable public static func present(_ error: Error) {
		Task { @MainActor in
			NSApplication.shared.presentError(error)
		}
	}

	public static func log(_ error: Error) {
		logger.error("\(error.localizedDescription)")
	}
}
