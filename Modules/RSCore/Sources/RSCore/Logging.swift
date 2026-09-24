//
//  Logging.swift
//  RSCore
//
//  Created by Brent Simmons on 8/2/26.
//

import Foundation
import os

public extension Logger {

	/// Subsystem for all NetNewsWire logging.
	///
	/// A constant rather than Bundle.main.bundleIdentifier so that logging works
	/// in processes without a bundle identifier (the Swift Testing runner, for instance)
	/// and so that one Console filter covers the apps and the extensions.
	static let nnwSubsystem = "com.ranchero.NetNewsWire"
}
