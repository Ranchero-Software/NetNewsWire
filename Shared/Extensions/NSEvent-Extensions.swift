//
//  NSEvent-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/26/22.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

extension NSEvent {
	
	var isRightClick: Bool {
		let rightClick = (self.type == .rightMouseDown)
		let controlClick = self.modifierFlags.contains(.control)
		return rightClick || controlClick
	}
	
}
