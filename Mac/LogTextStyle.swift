//
//  LogTextStyle.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 6/6/26.
//

import AppKit

/// Shared sizing and paragraph styling for log windows (Activity Log, Error Log) — both render a
/// stream of color-coded monospaced entries in a scrollable NSTextView with a Copy Contents bar
/// across the bottom.
enum LogTextStyle {

	static let fontSize: CGFloat = 16.0
	static let textContainerInset: CGFloat = 8
	/// Vertical nudge above the centered position used when first opening a log window.
	static let aboveCenterOffset: CGFloat = 40

	@MainActor static let entryParagraphStyle: NSParagraphStyle = {
		let style = NSMutableParagraphStyle()
		style.lineSpacing = 4
		style.paragraphSpacing = 7
		return style
	}()
}

extension NSTextView {

	/// True when the visible region reaches the bottom of the document (1pt tolerance).
	var isScrolledToBottom: Bool {
		guard let scrollView = enclosingScrollView else {
			return true
		}
		let visibleMaxY = scrollView.contentView.bounds.maxY
		let documentMaxY = frame.maxY
		return visibleMaxY >= documentMaxY - 1
	}

	/// Re-flow the text container to the current width during live resize.
	func updateContainerSizeForLiveResize() {
		guard let container = textContainer else {
			return
		}
		container.size = NSSize(width: bounds.width - textContainerInset.width * 2, height: .greatestFiniteMagnitude)
		layoutManager?.ensureLayout(for: container)
	}

	/// Copy the full text to the general pasteboard. No-op when empty.
	func copyAllToPasteboard() {
		guard !string.isEmpty else {
			return
		}
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(string, forType: .string)
	}
}

extension NSWindow {

	/// Center the window, then nudge above center by the given offset. Used on the first show
	/// of log windows.
	func centerAboveCenter(by offset: CGFloat) {
		center()
		var newFrame = frame
		newFrame.origin.y += offset
		setFrame(newFrame, display: false)
	}
}
