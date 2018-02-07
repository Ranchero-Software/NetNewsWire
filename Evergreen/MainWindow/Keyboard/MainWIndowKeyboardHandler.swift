//
//  MainWIndowKeyboardHandler.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

final class MainWindowKeyboardHandler: KeyboardDelegate {

	static let shared = MainWindowKeyboardHandler()
	let globalShortcuts: Set<KeyboardShortcut>

	init() {

		let f = Bundle.main.path(forResource: "GlobalKeyboardShortcuts", ofType: "plist")!
		let rawShortcuts = NSArray(contentsOfFile: f)! as! [[String: Any]]

		self.globalShortcuts = Set(rawShortcuts.compactMap { KeyboardShortcut(dictionary: $0) })
	}

	func keydown(_ event: NSEvent, in view: NSView) -> Bool {

		let key = KeyboardKey(with: event)
		guard let matchingShortcut = KeyboardShortcut.findMatchingShortcut(in: globalShortcuts, key: key) else {
			return false
		}

		matchingShortcut.perform(with: view)
		return true
	}
}

