//
//  SendToMicroBlogCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Foundation

// Not undoable.

struct SendToMicroBlogCommand: SendToCommand {

	func canSendObject(_ object: Any?) -> Bool {

		return false
	}
	
	func sendObject(_ object: Any?) {

	}
}

private extension SendToMicroBlogCommand {

	func appExists() {

		
	}
}
