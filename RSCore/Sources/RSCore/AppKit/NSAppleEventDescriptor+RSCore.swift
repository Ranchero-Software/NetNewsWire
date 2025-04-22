//
//  NSAppleEventDescriptor+RSCore.swift
//  RSCore
//
//  Created by Nate Weaver on 2020-01-02.
//  Copyright © 2020 Ranchero Software, LLC. All rights reserved.
//
#if os(macOS)
import AppKit

public extension NSAppleEventDescriptor {

	/// An NSAppleEventDescriptor describing a running application.
	///
	/// - Parameter runningApplication: A running application to associate with the descriptor.
	///
	/// - Returns: An instance of `NSAppleEventDescriptor` that refers to the running application,
	///   or `nil` if the running application has no process ID.
	convenience init?(runningApplication: NSRunningApplication) {

		let pid = runningApplication.processIdentifier
		if pid == -1 {
			return nil
		}

		self.init(processIdentifier: pid)
	}

}
#endif
