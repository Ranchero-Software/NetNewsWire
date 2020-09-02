//
//  SidebarCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/1/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore
import Account
import RSTree

class SidebarCell : NSTableCellView {

	var iconImage: IconImage? {
		didSet {
			updateFaviconImage()
		}
	}

	var shouldShowImage = false {
		didSet {
			if shouldShowImage != oldValue {
				needsLayout = true
			}
			faviconImageView.iconImage = shouldShowImage ? iconImage : nil
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

	private let faviconImageView = IconView()
	private let unreadCountView = UnreadCountView(frame: NSZeroRect)

	override var backgroundStyle: NSView.BackgroundStyle {
		didSet {
			updateFaviconImage()
		}
	}
	
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
		faviconImageView.setFrame(ifNotEqualTo: layout.faviconRect)
		titleView.setFrame(ifNotEqualTo: layout.titleRect)
		unreadCountView.setFrame(ifNotEqualTo: layout.unreadCountRect)
	}
	
	func updateFaviconImage() {
		var updatedIconImage = iconImage
		
		if let iconImage = iconImage, iconImage.isSymbol {
			if backgroundStyle != .normal {
				let image = iconImage.image.tinted(with: .white)
				updatedIconImage = IconImage(image, isSymbol: true)
			} else {
				if let preferredColor = iconImage.preferredColor {
					let image = iconImage.image.tinted(with: NSColor(cgColor: preferredColor)!)
					updatedIconImage = IconImage(image, isSymbol: true)
				} else {
					let image = iconImage.image.tinted(with: .controlAccentColor)
					updatedIconImage = IconImage(image, isSymbol: true)
				}
			}
		}

		if let image = updatedIconImage {
			faviconImageView.iconImage = shouldShowImage ? image : nil
		} else {
			faviconImageView.iconImage = nil
		}
	}
	
}

