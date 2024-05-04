//
//  SendToCommand.swift
//  RSCore
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

#if os(macOS)
import AppKit
#endif

#if os(iOS)
import UIKit
#endif

/// A type that sends an object's data to an external application.
///
/// Unlike UndoableCommand commands, you instantiate one of each of these and reuse them.
///
/// See NetNewsWire.

public protocol SendToCommand {

	/// The title of the command.
	///
	/// Often the name of the target application.
	var title: String { get }
	/// The image for the command.
	///
	/// Often the icon of the target application.
	@MainActor var image: RSImage? { get }

	/// Determine whether an object can be sent to the target application.
	///
	/// - Parameters:
	///   - object: The object to test.
	///   - selectedText: The currently selected text.
	/// - Returns: `true` if the object can be sent, `false` otherwise.
	@MainActor func canSendObject(_ object: Any?, selectedText: String?) -> Bool

	/// Send an object to the target application.
	///
	///	- Parameters:
	///   - object: The object whose data to send.
	///   - selectedText: The currently selected text.
	@MainActor func sendObject(_ object: Any?, selectedText: String?)
}

