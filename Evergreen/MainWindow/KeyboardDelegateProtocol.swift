//
//  KeyboardDelegateProtocol.swift
//  Evergreen
//
//  Created by Brent Simmons on 10/11/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

let keypadEnter: unichar = 3

protocol KeyboardDelegate: class {
	
	// Return true if handled.
	func handleKeydownEvent(_: NSEvent, sender: AnyObject) -> Bool
}
