//
//  SidebarCell.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import DB5

private var textSizeCache = [String: NSSize]()

class SidebarCell : NSTableCellView {
	
	var image: NSImage? {
		didSet {
			if let image = image {
				imageView?.image = shouldShowImage ? image : nil
				imageView?.alphaValue = image.isTemplate ? 0.75 : 1.0
			}
			else {
				imageView?.image = nil
				imageView?.alphaValue = 1.0
			}
		}
	}

	var shouldShowImage = false {
		didSet {
			if shouldShowImage != oldValue {
				needsLayout = true
			}
			imageView?.image = shouldShowImage ? image : nil
		}
	}

	private let unreadCountView = UnreadCountView(frame: NSZeroRect)

	var cellAppearance: SidebarCellAppearance! {
		didSet {
			if cellAppearance != oldValue {
				needsLayout = true
			}
		}
	}

	var unreadCount: Int {
		get {
			return unreadCountView.unreadCount
		}
		set {
			if unreadCountView.unreadCount != newValue {
				unreadCountView.unreadCount = newValue
				unreadCountView.isHidden = (newValue < 1)
				needsLayout = true
			}
		}
	}

	var name: String {
		get {
			if let s = textField?.stringValue {
				return s
			}
			return ""
		}
		set {
			if textField?.stringValue != newValue {
				textField?.stringValue = newValue
				needsDisplay = true
				needsLayout = true
			}
		}
	}

	override var isFlipped: Bool {
		get {
			return true
		}
	}
	
	private func commonInit() {
		
		unreadCountView.translatesAutoresizingMaskIntoConstraints = false
		addSubview(unreadCountView)
	}
	
	override init(frame frameRect: NSRect) {
		
		super.init(frame: frameRect)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		
		super.init(coder: coder)
		commonInit()
	}

	override func layout() {

		resizeSubviews(withOldSize: NSZeroSize)
	}

	override func resizeSubviews(withOldSize oldSize: NSSize) {

		guard let textField = textField else {
			return
		}
		let layout = SidebarCellLayout(appearance: cellAppearance, cellSize: bounds.size, shouldShowImage: shouldShowImage, textField: textField, unreadCountView: unreadCountView)
		layoutWith(layout)
	}
}

private extension SidebarCell {

	func layoutWith(_ layout: SidebarCellLayout) {

		imageView?.rs_setFrameIfNotEqual(layout.faviconRect)
		textField?.rs_setFrameIfNotEqual(layout.titleRect)
		unreadCountView.rs_setFrameIfNotEqual(layout.unreadCountRect)
	}
}

