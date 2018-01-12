//
//  SendToMarsEditCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

final class SendToMarsEditCommand: SendToCommand {

	let title = NSLocalizedString("Send to MarsEdit", comment: "Send to command")

	var image: NSImage? {
		return appSpecifierToUse()?.icon ?? nil
	}

	private let marsEditApps = [ApplicationSpecifier(bundleID: "com.red-sweater.marsedit4"), ApplicationSpecifier(bundleID: "com.red-sweater.marsedit")]

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool {

		if let _ = appSpecifierToUse() {
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

	func appSpecifierToUse() -> ApplicationSpecifier? {

		for specifier in marsEditApps {
			specifier.update()
			if specifier.existsOnDisk {
				return specifier
			}
		}

		return nil
	}
}
