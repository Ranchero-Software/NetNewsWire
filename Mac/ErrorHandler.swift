//
//  ErrorHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import RSCore
import AppKit
import Account
import os

struct ErrorHandler: Sendable {

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ErrorHandler")

	@Sendable public static func present(_ error: Error) {
		Task { @MainActor in
			NSApplication.shared.presentError(errorForPresentation(error))
		}
	}

	public static func log(_ error: Error) {
		logger.error("\(error.localizedDescription)")
	}

	// Drop a recovery suggestion when there are no recovery options to act on it.
	private static func errorForPresentation(_ error: Error) -> NSError {
		let nsError = error as NSError
		guard nsError.localizedRecoverySuggestion != nil, nsError.localizedRecoveryOptions == nil else {
			return nsError
		}
		var userInfo = nsError.userInfo
		userInfo[NSLocalizedDescriptionKey] = nsError.localizedDescription
		userInfo[NSLocalizedRecoverySuggestionErrorKey] = nil
		return NSError(domain: nsError.domain, code: nsError.code, userInfo: userInfo)
	}
}
