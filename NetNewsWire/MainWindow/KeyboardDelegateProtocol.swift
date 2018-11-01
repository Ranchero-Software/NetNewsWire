//
//  KeyboardDelegateProtocol.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

let keypadEnter: unichar = 3

@objc protocol KeyboardDelegate: class {

	// Return true if handled.
	func keydown(_: NSEvent, in view: NSView) -> Bool
}
