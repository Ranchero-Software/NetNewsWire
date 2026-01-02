//
//  LinkLabel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

final class LinkLabel: NSTextField {

	/// Les pièces de résistance — keeping it a Mac-assed Mac app.
	override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
