//
//  SendToMarsEditCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa
import RSCore

final class SendToMarsEditCommand: SendToCommand {

	let title = NSLocalizedString("Send to MarsEdit", comment: "Send to command")

	var image: NSImage? {
		return appToUse()?.icon ?? nil
	}

	private let marsEditApps = [UserApp(bundleID: "com.red-sweater.marsedit4"), UserApp(bundleID: "com.red-sweater.marsedit")]

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		if let _ = appToUse() {
			return true
		}
		return false
	}

	func sendObject(_ object: Any?, selectedText: String?) {

		if !canSendObject(object, selectedText: selectedText) {
			return
		}
	}
}

private extension SendToMarsEditCommand {

	func appToUse() -> UserApp? {

		for app in marsEditApps {
			app.updateStatus()
			if app.isRunning {
				return app
			}
			if app.existsOnDisk {
				return app
			}
		}

		return nil
	}
}
