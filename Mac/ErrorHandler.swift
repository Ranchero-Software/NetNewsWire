//
//  ErrorHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account
import RSCore

struct ErrorHandler: Logging {

	public static func present(_ error: Error) {
		NSApplication.shared.presentError(error)
	}

	public static func log(_ error: Error) {
		ErrorHandler.logger.error("\(error.localizedDescription, privacy: .public)")
	}
}
