//
//  SendToMarsEditCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

final class SendToMarsEditCommand: SendToCommand {

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		return false
	}

	func sendObject(_ object: Any?, selectedText: String?) {

	}
}
