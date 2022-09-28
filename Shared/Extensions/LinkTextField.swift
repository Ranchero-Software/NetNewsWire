//
//  LinkTextField.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 9/27/22.
//  Copyright © 2022 Ranchero Software. All rights reserved.
//

import Foundation

class LinkTextField: NSTextField {
	
	override func resetCursorRects() {
		addCursorRect(bounds, cursor: NSCursor.pointingHand)
	}
	
}
