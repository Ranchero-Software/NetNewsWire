//
//  NSResponder-Extensions.swift
//  RSCore
//
//  Created by Brent Simmons on 10/10/16.
//  Copyright © 2016 Ranchero Software, LLC. All rights reserved.
//

import AppKit

public extension NSResponder {
	
	public func hasAncestor(_ ancestor: NSResponder) -> Bool {
		
		var nomad: NSResponder = self
		while(true) {
			if nomad === ancestor {
				return true
			}
			if let _ = nomad.nextResponder {
				nomad = nomad.nextResponder!
			}
			else {
				break
			}
		}
		
		return false
	}
}
