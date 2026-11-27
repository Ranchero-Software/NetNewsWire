//
//  LinkButton.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 11/27/26.
//

import AppKit

/// A button that acts like a link, matching `LinkLabel`: pointing-hand cursor, and highlighted and underlined while pressed.
final class LinkButton: NSButton {
	private var isTracking = false
	private var isShowingHighlight = false
	private var originalAttributedTitle: NSAttributedString?

	override func resetCursorRects() {
		addCursorRect(bounds, cursor: .pointingHand)
	}

	override func mouseDown(with event: NSEvent) {
		guard isEnabled else {
			return
		}
		isTracking = true
		highlightLink()
	}

	override func mouseDragged(with event: NSEvent) {
		guard isTracking else {
			return
		}

		let isInside = isMouseInside(event)
		if isInside && !isShowingHighlight {
			highlightLink()
		} else if !isInside && isShowingHighlight {
			unhighlightLink()
		}
	}

	override func mouseUp(with event: NSEvent) {
		guard isTracking else {
			return
		}
		isTracking = false

		if isShowingHighlight {
			unhighlightLink()
		}
		if isMouseInside(event) {
			sendAction(action, to: target)
		}
	}
}

private extension LinkButton {
	func isMouseInside(_ event: NSEvent) -> Bool {
		bounds.contains(convert(event.locationInWindow, from: nil))
	}

	func highlightLink() {
		originalAttributedTitle = attributedTitle

		let highlightedTitle = NSMutableAttributedString(attributedString: attributedTitle)
		let fullRange = NSRange(location: 0, length: highlightedTitle.length)
		highlightedTitle.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: fullRange)
		highlightedTitle.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: fullRange)
		highlightedTitle.addAttribute(.underlineColor, value: NSColor.systemOrange, range: fullRange)
		attributedTitle = highlightedTitle

		isShowingHighlight = true
	}

	func unhighlightLink() {
		if let originalAttributedTitle {
			attributedTitle = originalAttributedTitle
		}
		originalAttributedTitle = nil
		isShowingHighlight = false
	}
}
