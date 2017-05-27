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
	
	var image: NSImage?
	private let unreadCountView = UnreadCountView(frame: NSZeroRect)

	var unreadCount: Int {
		get {
			return unreadCountView.unreadCount
		}
		set {
			if unreadCountView.unreadCount != newValue {
				unreadCountView.unreadCount = newValue
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
	
	private let kTextFieldOriginX: CGFloat = 4.0
	private let kTextFieldMarginRight: CGFloat = 4.0
	private let kUnreadCountMarginLeft: CGFloat = 4.0
	private let kUnreadCountMarginRight: CGFloat = 4.0
	
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		
		var r = textField!.frame
		r.origin.x = kTextFieldOriginX
		r.size.width = NSWidth(bounds) - (kTextFieldOriginX + kTextFieldMarginRight);
		
		let unreadCountSize = unreadCountView.intrinsicContentSize
		if unreadCountSize.width > 0.1 {
			r.size.width = NSWidth(bounds) - (kTextFieldOriginX + kUnreadCountMarginLeft + unreadCountSize.width + kUnreadCountMarginRight)
		}

		let size = textField!.intrinsicContentSize
		r.size.height = size.height
		r = rs_rectCenteredVertically(r)
		r.origin.y -= 1.0
		
		textField?.rs_setFrameIfNotEqual(r)

		layoutUnreadCountView(unreadCountSize)
	}
	
	private func layoutUnreadCountView(_ size: NSSize) {
		
		if size == NSZeroSize {
			if !unreadCountView.isHidden {
				unreadCountView.isHidden = true
			}
			return
		}
		
		if unreadCountView.isHidden {
			unreadCountView.isHidden = false
		}
		
		var r = NSZeroRect
		r.size = size
		r.origin.x = NSMaxX(textField!.frame) + kUnreadCountMarginLeft
		r = rs_rectCenteredVertically(r)
		
		unreadCountView.rs_setFrameIfNotEqual(r)
	}
}




