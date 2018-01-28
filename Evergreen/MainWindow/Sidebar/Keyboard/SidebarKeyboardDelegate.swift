//
//  SidebarKeyboardDelegate.swift
//  Evergreen
//
//  Created by Brent Simmons on 12/19/17.
//  Copyright © 2017 Ranchero Software. All rights reserved.
//

import Cocoa
import RSCore

@objc final class SidebarKeyboardDelegate: NSObject, KeyboardDelegate {

	@IBOutlet weak var sidebarViewController: SidebarViewController?
	let shortcuts: Set<KeyboardShortcut>

	override init() {

		let f = Bundle.main.path(forResource: "SidebarKeyboardShortcuts", ofType: "plist")!
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

