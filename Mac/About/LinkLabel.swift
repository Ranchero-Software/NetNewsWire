//
//  LinkLabel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//


class LinkLabel: NSTextField {

	/// pièces de résistance -- keeping it a mac-assed mac app.
	override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
