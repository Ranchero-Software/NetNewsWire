//
//  ErrorHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import os.log

struct ErrorHandler {

	private static var log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "Account")

	public static func present(_ viewController: UIViewController) -> (Error) -> () {
		return { [weak viewController] error in
			viewController?.presentError(error)
		}
	}
		
	public static func log(_ error: Error) {
		os_log(.error, log: self.log, "%@", error.localizedDescription)
	}

}
