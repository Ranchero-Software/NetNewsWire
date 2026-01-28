//
//  LinkLabel.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 26/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import AppKit
import RSWeb

final class LinkLabel: NSTextField {
	private var linkURL: URL?
	private var originalAttributedString: NSAttributedString?
	private var isShowingHighlight = false

	/// La pièce de résistance — keeping it a Mac-assed Mac app.
	override func resetCursorRects() {
		addCursorRect(bounds, cursor: .pointingHand)
	}

	override func mouseDown(with event: NSEvent) {
		if linkURL == nil {
			linkURL = attributedStringValue.attribute(.link, at: 0, effectiveRange: nil) as? URL
		}
		if originalAttributedString == nil {
			originalAttributedString = attributedStringValue
		}
		highlight()
	}

	override func mouseDragged(with event: NSEvent) {
		let locationInView = convert(event.locationInWindow, from: nil)
		let isInside = bounds.contains(locationInView)

		if isInside && !isShowingHighlight {
			highlight()
		} else if !isInside && isShowingHighlight {
			unhighlight()
		}
	}

	override func mouseUp(with event: NSEvent) {
		let locationInView = convert(event.locationInWindow, from: nil)
		let isInside = bounds.contains(locationInView)

		unhighlight()

		if isInside, let linkURL {
			MacWebBrowser.openURL(linkURL, inBackground: false)
		}
	}
}

private extension LinkLabel {
	func highlight() {
		changeColor(.systemOrange)
		isShowingHighlight = true
	}

	func unhighlight() {
		if let originalAttributedString {
			attributedStringValue = originalAttributedString
		}
		isShowingHighlight = false
	}

	func changeColor(_ color: NSColor) {
		let styledString = NSMutableAttributedString(string: stringValue)
		let fullRange = NSRange(location: 0, length: styledString.length)

		if let font {
			styledString.addAttribute(.font, value: font, range: fullRange)
		}
		styledString.addAttribute(.foregroundColor, value: color, range: fullRange)
		styledString.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
		styledString.addAttribute(.underlineColor, value: color, range: fullRange)

		attributedStringValue = styledString
	}
}
