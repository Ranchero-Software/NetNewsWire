//
//  SendToCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import AppKit

// Unlike UndoableCommand commands, you instantiate one of each of these and reuse them.

protocol SendToCommand {

	var title: String { get }
	var image: NSImage? { get }

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool
	func sendObject(_ object: Any?, selectedText: String?)
}

