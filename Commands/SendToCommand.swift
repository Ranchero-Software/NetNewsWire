//
//  SendToCommand.swift
//  Evergreen
//
//  Created by Brent Simmons on 1/8/18.
//  Copyright © 2018 Ranchero Software. All rights reserved.
//

import Cocoa

// Unlike UndoableCommand commands, you instantiate one of each of these and reuse them.

protocol SendToCommand {

	var title: String { get }
	var image: NSImage? { get }

	func canSendObject(_ object: Any?, selectedText: String?) -> Bool
	func sendObject(_ object: Any?, selectedText: String?)
}


final class ApplicationSpecifier {

	let bundleID: String
	var icon: NSImage? = nil
	var existsOnDisk = false
	var path: String? = nil

	init(bundleID: String) {

		self.bundleID = bundleID
		update()
	}

	func update() {

		path = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: bundleID)
		if let path = path {
			if icon == nil {
				icon = NSWorkspace.shared.icon(forFile: path)
			}
			existsOnDisk = true
		}
		else {
			existsOnDisk = false
			icon = nil
		}
	}

	func launch() -> Bool {

		guard existsOnDisk, let path = path else {
			return false
		}

		let url = URL(fileURLWithPath: path)
		if let runningApplication = try? NSWorkspace.shared.launchApplication(at: url, options: [.withErrorPresentation], configuration: [:]) {
			if runningApplication.isFinishedLaunching {
				return true
			}
			sleep(3) // Give the app time to launch. This is ugly.
			return true
		}
		return false
	}
}
