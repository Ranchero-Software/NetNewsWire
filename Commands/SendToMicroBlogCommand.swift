//
//  SendToMicroBlogCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

// Not undoable.

final class SendToMicroBlogCommand: SendToCommand {

	private let bundleID = "blog.micro.mac"
	private var appExists = false

	init() {

		self.appExists = appExistsOnDisk(bundleID)
		NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive(_:)), name: NSApplication.didBecomeActiveNotification, object: nil)
	}

	func canSendObject(_ object: Any?) -> Bool {

		if !appExists {
			return false
		}
		return false
	}
	
	func sendObject(_ object: Any?) {

	}

	@objc func appDidBecomeActive(_ note: Notification) {

		self.appExists = appExistsOnDisk(bundleID)
	}
}


