//
//  SendToCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

// Unlike UndoableCommand commands, you instantiate one of each of these and reuse them.

protocol SendToCommand {

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool
	func sendObject(_ object: Any?, selectedText: String?)
}

extension SendToCommand {

	func appExistsOnDisk(_ bundleIdentifier: String) -> Bool {

		if let _ = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleIdentifier) {
			return true
		}
		return false
	}
}
