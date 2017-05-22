//
//  NSWindow-Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 10/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import Cocoa

public extension NSWindow {
	
	public func makeFirstResponderUnlessDescendantIsFirstResponder(_ responder: NSResponder) {
		
		if !firstResponder.hasAncestor(responder) {
			makeFirstResponder(responder)
		}
	}
}
