//
//  ErrorHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 6/28/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import os.log

struct ErrorHandler {

	private static var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Application")

	public static func log(_ error: Error) {
		os_log(.error, log: self.log, "%@", error.localizedDescription)
	}

}
