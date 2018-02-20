//
//  TimelineTableCellView.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

class TimelineTableCellView: NSTableCellView {

	private let titleView = TimelineTableCellView.multiLineTextField()
	private let unreadIndicatorView = UnreadIndicatorView(frame: NSZeroRect)
	private let dateView = TimelineTableCellView.singleLineTextField()
	private let feedNameView = TimelineTableCellView.singleLineTextField()
	private let avatarImageView = TimelineTableCellView.imageView(with: AppImages.genericFeedImage, scaling: .scaleProportionallyDown)
	private let starView = TimelineTableCellView.imageView(with: AppImages.timelineStar, scaling: .scaleNone)

	private lazy var textFields = {
		return [self.dateView, self.feedNameView, self.titleView]
	}()

	var cellAppearance: TimelineCellAppearance! {
		didSet {
			updateTextFields()
			needsLayout = true
		}
	}
	
	var cellData: TimelineCellData! {
		didSet {
			updateSubviews()
		}
	}
	
	override var isFlipped: Bool {
		return true
	}

	override var isOpaque: Bool {
		return true
	}

	override var wantsUpdateLayer: Bool {
		return true
	}

	var isEmphasized = false {
		didSet {
//			titleView.emphasized = isEmphasized
			unreadIndicatorView.isEmphasized = isEmphasized
			updateTextFieldColors()
			needsDisplay = true
		}
	}
	
	var isSelected = false {
		didSet {
//			titleView.selected = isSelected
			unreadIndicatorView.isSelected = isSelected
			updateTextFieldColors()
			needsDisplay = true
		}
	}

	override init(frame frameRect: NSRect) {
		
		super.init(frame: frameRect)
		commonInit()
	}
	
	required init?(coder: NSCoder) {
		
		super.init(coder: coder)
		commonInit()
	}
	
	override func setFrameSize(_ newSize: NSSize) {
		
		if newSize == self.frame.size {
			return
		}
		
		super.setFrameSize(newSize)
		needsLayout = true
	}

	override func viewDidMoveToSuperview() {
		
		updateSubviews()
		updateAppearance()
	}
	
	override func layout() {

		resizeSubviews(withOldSize: NSZeroSize)
	}
	
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		
		let layoutRects = updatedLayoutRects()
		titleView.rs_setFrameIfNotEqual(layoutRects.titleRect)
		unreadIndicatorView.rs_setFrameIfNotEqual(layoutRects.unreadIndicatorRect)
		dateView.rs_setFrameIfNotEqual(layoutRects.dateRect)
		feedNameView.rs_setFrameIfNotEqual(layoutRects.feedNameRect)
		avatarImageView.rs_setFrameIfNotEqual(layoutRects.avatarImageRect)
		starView.rs_setFrameIfNotEqual(layoutRects.starRect)
	}

	override func updateLayer() {

		let color: NSColor
		if isSelected {
			color = isEmphasized ? NSColor.alternateSelectedControlColor : NSColor.secondarySelectedControlColor
		}
		else {
			color = NSColor.white
		}

		if layer?.backgroundColor != color.cgColor {
			layer?.backgroundColor = color.cgColor
		}
	}
}

// MARK: - Private

private extension TimelineTableCellView {

	static func singleLineTextField() -> NSTextField {

		let textField = NSTextField(labelWithString: "")
		textField.usesSingleLineMode = true
		textField.maximumNumberOfLines = 1
		textField.isEditable = false
		textField.lineBreakMode = .byTruncatingTail
		return textField
	}

	static func multiLineTextField() -> NSTextField {

		let textField = NSTextField(wrappingLabelWithString: "")
		textField.usesSingleLineMode = false
		textField.maximumNumberOfLines = 2
		textField.isEditable = false
		textField.lineBreakMode = .byTruncatingTail
		textField.cell?.truncatesLastVisibleLine = true
		return textField
	}

	static func imageView(with image: NSImage?, scaling: NSImageScaling) -> NSImageView {

		let imageView = image != nil ? NSImageView(image: image!) : NSImageView(frame: NSRect.zero)
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.imageScaling = scaling
		return imageView
	}

	func updateTextFieldColors() {

		updateTitleView()
		
		if isEmphasized && isSelected {
			textFields.forEach { $0.textColor = NSColor.white }
		}
		else {
			feedNameView.textColor = cellAppearance.feedNameColor
			dateView.textColor = cellAppearance.dateColor
		}
	}

	func updateTextFieldFonts() {

		feedNameView.font = cellAppearance.feedNameFont
		dateView.font = cellAppearance.dateFont
	}

	func updateTextFields() {

		updateTextFieldColors()
		updateTextFieldFonts()
	}

	func addSubviewAtInit(_ view: NSView, hidden: Bool) {

		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isHidden = hidden
	}

	func commonInit() {

		addSubviewAtInit(titleView, hidden: false)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(avatarImageView, hidden: false)
		addSubviewAtInit(starView, hidden: false)
	}

	func updatedLayoutRects() -> TimelineCellLayout {

		return TimelineCellLayout(width: bounds.width, cellData: cellData, appearance: cellAppearance)
	}

	func updateAppearance() {

		if let rowView = superview as? NSTableRowView {
			isEmphasized = rowView.isEmphasized
			isSelected = rowView.isSelected
		}
		else {
			isEmphasized = false
			isSelected = false
		}
	}

	func updateTitleView() {

		if isEmphasized && isSelected {
			if let attributedTitle = cellData?.attributedTitle {
				titleView.attributedStringValue = attributedTitle.rs_attributedStringByMakingTextWhite()
			}
		}
		else {
			if let attributedTitle = cellData?.attributedTitle {
				titleView.attributedStringValue = attributedTitle
			}
		}

		needsLayout = true
	}

	func updateDateView() {

		dateView.stringValue = cellData.dateString
		needsLayout = true
	}

	func updateFeedNameView() {

		if cellData.showFeedName {
			if feedNameView.isHidden {
				feedNameView.isHidden = false
			}
			feedNameView.stringValue = cellData.feedName
		}
		else {
			if !feedNameView.isHidden {
				feedNameView.isHidden = true
			}
		}
	}

	func updateUnreadIndicator() {

		let shouldHide = cellData.read || cellData.starred
		if unreadIndicatorView.isHidden != shouldHide {
			unreadIndicatorView.isHidden = shouldHide
		}
	}

	func updateStarView() {

		starView.isHidden = !cellData.starred
	}

	func updateAvatar() {

		if !cellData.showAvatar {
			avatarImageView.image = nil
			avatarImageView.isHidden = true
			return
		}

		avatarImageView.isHidden = false

		if let image = cellData.avatar {
			if avatarImageView.image !== image {
				avatarImageView.image = image
			}
		}
		else {
			avatarImageView.image = nil
		}

		avatarImageView.wantsLayer = true
		avatarImageView.layer?.cornerRadius = cellAppearance.avatarCornerRadius
	}

	func updateSubviews() {

		updateTitleView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateStarView()
		updateAvatar()
	}
}
