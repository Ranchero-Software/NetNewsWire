//
//  ErrorHandler.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 5/26/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import Account

struct ErrorHandler {

	public static func present(_ error: Error) {
		NSApplication.shared.presentError(error)
	}
	
}
