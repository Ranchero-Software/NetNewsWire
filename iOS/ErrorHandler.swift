//
//  ErrorHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import os
import RSCore

struct ErrorHandler {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "ErrorHandler")

	public static func present(_ viewController: UIViewController) -> (Error) -> () {
		return { [weak viewController] error in
			if UIApplication.shared.applicationState == .active {
				viewController?.presentError(error)
			} else {
				log(error)
			}
		}
	}

	public static func log(_ error: Error) {
		logger.error("\(error.localizedDescription)")
	}
}
