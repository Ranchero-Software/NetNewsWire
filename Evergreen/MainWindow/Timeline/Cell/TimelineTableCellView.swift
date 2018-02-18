//
//  TimelineTableCellView.swift
//  Evergreen
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSTextDrawing

class TimelineTableCellView: NSTableCellView {

	private let titleView = RSMultiLineView(frame: NSZeroRect)
	private let unreadIndicatorView = UnreadIndicatorView(frame: NSZeroRect)
	private let dateView = RSSingleLineView(frame: NSZeroRect)
	private let feedNameView = RSSingleLineView(frame: NSZeroRect)

	private let avatarImageView: NSImageView = {
		let imageView = NSImageView(frame: NSRect.zero)
		imageView.imageScaling = .scaleProportionallyDown
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.image = AppImages.genericFeedImage
		return imageView
	}()

	private let starView: NSImageView = {
		let imageView = NSImageView(frame: NSRect.zero)
		imageView.imageScaling = .scaleNone
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.image = AppImages.timelineStar
		return imageView
	}()

	var cellAppearance: TimelineCellAppearance! {
		didSet {
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
			dateView.emphasized = isEmphasized
			feedNameView.emphasized = isEmphasized
			titleView.emphasized = isEmphasized
			unreadIndicatorView.isEmphasized = isEmphasized
			needsDisplay = true
		}
	}
	
	var isSelected = false {
		didSet {
			dateView.selected = isSelected
			feedNameView.selected = isSelected
			titleView.selected = isSelected
			unreadIndicatorView.isSelected = isSelected
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

		return timelineCellLayout(NSWidth(bounds), cellData: cellData, appearance: cellAppearance)
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

		titleView.attributedStringValue = cellData.attributedTitle
		needsLayout = true
	}

	func updateDateView() {

		dateView.attributedStringValue = cellData.attributedDateString
		needsLayout = true
	}

	func updateFeedNameView() {

		if cellData.showFeedName {
			if feedNameView.isHidden {
				feedNameView.isHidden = false
			}
			feedNameView.attributedStringValue = cellData.attributedFeedName
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
