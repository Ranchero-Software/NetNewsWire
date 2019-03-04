//
//  DetailKeyboardDelegate.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 3/1/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import RSCore

@objc final class DetailKeyboardDelegate: NSObject, KeyboardDelegate {

	let shortcuts: Set<KeyboardShortcut>

	override init() {

		let f = Bundle.main.path(forResource: "DetailKeyboardShortcuts", ofType: "plist")!
		let rawShortcuts = NSArray(contentsOfFile: f)! as! [[String: Any]]

		self.shortcuts = Set(rawShortcuts.compactMap { KeyboardShortcut(dictionary: $0) })

		super.init()
	}

	func keydown(_ event: NSEvent, in view: NSView) -> Bool {

		if MainWindowKeyboardHandler.shared.keydown(event, in: view) {
			return true
		}

		let key = KeyboardKey(with: event)
		guard let matchingShortcut = KeyboardShortcut.findMatchingShortcut(in: shortcuts, key: key) else {
			return false
		}

		matchingShortcut.perform(with: view)
		return true
	}
}
