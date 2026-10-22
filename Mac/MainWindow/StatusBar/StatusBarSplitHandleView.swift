//
//  StatusBarSplitHandleView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 10/11/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import AppKit

@MainActor protocol StatusBarSplitHandleViewDelegate: AnyObject {
	func splitHandleView(_ splitHandleView: StatusBarSplitHandleView, didDragBy distance: CGFloat)
	func splitHandleViewDidBeginDragging(_ splitHandleView: StatusBarSplitHandleView)
}

/// An invisible area in the status bar covering the ||| grip and the sidebar divider. Dragging it moves the divider.
final class StatusBarSplitHandleView: NSView {

	weak var delegate: StatusBarSplitHandleViewDelegate?

	private var dragStartX: CGFloat = 0

	override func resetCursorRects() {
		addCursorRect(bounds, cursor: .columnResize)
	}

	override func mouseDown(with event: NSEvent) {
		dragStartX = event.locationInWindow.x
		delegate?.splitHandleViewDidBeginDragging(self)
	}

	override func mouseDragged(with event: NSEvent) {
		delegate?.splitHandleView(self, didDragBy: event.locationInWindow.x - dragStartX)
	}
}
