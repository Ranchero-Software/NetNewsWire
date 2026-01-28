//
//  LinksTextView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 01/04/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit
import RSWeb

final class LinksTextView: NSTextView {
	private var clickedLinkRange: NSRange?
	private var clickedLinkURL: URL?
	private var originalLinkAttributes: [NSAttributedString.Key: Any]?
	private var isShowingHighlight = false

	override func mouseDown(with event: NSEvent) {
		let point = convert(event.locationInWindow, from: nil)
		let characterIndex = characterIndexForInsertion(at: point)

		guard characterIndex < textStorage?.length ?? 0 else {
			super.mouseDown(with: event)
			return
		}

		var effectiveRange = NSRange()
		if let url = textStorage?.attribute(.link, at: characterIndex, effectiveRange: &effectiveRange) as? URL {
			clickedLinkRange = effectiveRange
			clickedLinkURL = url

			// Save original attributes
			originalLinkAttributes = textStorage?.attributes(at: characterIndex, effectiveRange: nil)

			highlight()
		} else {
			super.mouseDown(with: event)
		}
	}

	override func mouseDragged(with event: NSEvent) {
		guard let range = clickedLinkRange else {
			super.mouseDragged(with: event)
			return
		}

		let point = convert(event.locationInWindow, from: nil)
		let characterIndex = characterIndexForInsertion(at: point)
		let isOverLink = characterIndex >= range.location && characterIndex < range.location + range.length

		if isOverLink && !isShowingHighlight {
			highlight()
		} else if !isOverLink && isShowingHighlight {
			unhighlight()
		}
	}

	override func mouseUp(with event: NSEvent) {
		guard let range = clickedLinkRange, let url = clickedLinkURL else {
			super.mouseUp(with: event)
			return
		}

		// Restore original attributes
		unhighlight()

		// Check if mouse is still over the link
		let point = convert(event.locationInWindow, from: nil)
		let characterIndex = characterIndexForInsertion(at: point)

		if characterIndex >= range.location && characterIndex < range.location + range.length {
			MacWebBrowser.openURL(url, inBackground: false)
		}

		clickedLinkRange = nil
		clickedLinkURL = nil
		originalLinkAttributes = nil
	}
}

private extension LinksTextView {
	func highlight() {
		guard let range = clickedLinkRange, let textStorage else {
			return
		}

		textStorage.removeAttribute(.link, range: range)
		textStorage.addAttribute(.foregroundColor, value: NSColor.systemOrange, range: range)
		textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
		textStorage.addAttribute(.underlineColor, value: NSColor.systemOrange, range: range)

		isShowingHighlight = true
	}

	func unhighlight() {
		isShowingHighlight = false

		guard let range = clickedLinkRange, let originalLinkAttributes, let textStorage else {
			return
		}

		// Remove added attributes
		textStorage.removeAttribute(.foregroundColor, range: range)
		textStorage.removeAttribute(.underlineStyle, range: range)
		textStorage.removeAttribute(.underlineColor, range: range)

		// Restore original attributes
		textStorage.addAttributes(originalLinkAttributes, range: range)
	}
}
