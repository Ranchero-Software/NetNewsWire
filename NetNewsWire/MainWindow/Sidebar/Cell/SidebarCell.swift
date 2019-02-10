//
//  SidebarCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import DB5
import Account
import RSTree

class SidebarCell : NSTableCellView {

	var image: NSImage? {
		didSet {
			if let image = image {
				faviconImageView.image = shouldShowImage ? image : nil
				faviconImageView.alphaValue = image.isTemplate ? 0.75 : 1.0
			}
			else {
				faviconImageView.image = nil
				faviconImageView.alphaValue = 1.0
			}
		}
	}

	var shouldShowImage = false {
		didSet {
			if shouldShowImage != oldValue {
				needsLayout = true
			}
			faviconImageView.image = shouldShowImage ? image : nil
		}
	}


	var cellAppearance: SidebarCellAppearance? {
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
			return titleView.stringValue
		}
		set {
			if titleView.stringValue != newValue {
				titleView.stringValue = newValue
				needsDisplay = true
				needsLayout = true
			}
		}
	}

	private let titleView: NSTextField = {
		let textField = NSTextField(labelWithString: "")
		textField.usesSingleLineMode = true
		textField.maximumNumberOfLines = 1
		textField.isEditable = false
		textField.lineBreakMode = .byTruncatingTail
		textField.allowsDefaultTighteningForTruncation = false
		return textField
	}()

	private let faviconImageView: NSImageView = {
		let image = AppImages.genericFeedImage
		let imageView = image != nil ? NSImageView(image: image!) : NSImageView(frame: NSRect.zero)
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.imageScaling = .scaleProportionallyDown
		imageView.wantsLayer = true
		return imageView
	}()

	private let unreadCountView = UnreadCountView(frame: NSZeroRect)

	override var isFlipped: Bool {
		return true
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

		guard let cellAppearance = cellAppearance else {
			return
		}
		let layout = SidebarCellLayout(appearance: cellAppearance, cellSize: bounds.size, shouldShowImage: shouldShowImage, textField: titleView, unreadCountView: unreadCountView)
		layoutWith(layout)
	}

	override func accessibilityLabel() -> String? {
		if unreadCount > 0 {
			let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessiblity")
			return "\(name) \(unreadCount) \(unreadLabel)"
		} else {
			return name
		}
	}
}

private extension SidebarCell {

	func commonInit() {
		addSubviewAtInit(unreadCountView)
		addSubviewAtInit(faviconImageView)
		addSubviewAtInit(titleView)
	}

	func addSubviewAtInit(_ view: NSView) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
	}

	func layoutWith(_ layout: SidebarCellLayout) {
		faviconImageView.rs_setFrameIfNotEqual(layout.faviconRect)
		titleView.rs_setFrameIfNotEqual(layout.titleRect)
		unreadCountView.rs_setFrameIfNotEqual(layout.unreadCountRect)
	}
}

