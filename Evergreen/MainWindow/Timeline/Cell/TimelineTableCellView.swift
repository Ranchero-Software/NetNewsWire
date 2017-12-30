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

	let titleView = RSMultiLineView(frame: NSZeroRect)
	let unreadIndicatorView = UnreadIndicatorView(frame: NSZeroRect)
	let dateView = RSSingleLineView(frame: NSZeroRect)
	let feedNameView = RSSingleLineView(frame: NSZeroRect)

	let avatarImageView: NSImageView = {
		let imageView = NSImageView(frame: NSRect.zero)
		imageView.imageScaling = .scaleProportionallyDown
		imageView.animates = false
		imageView.imageAlignment = .alignTop
		return imageView
	}()

	let faviconImageView: NSImageView = {
		let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 16, height: 16))
		imageView.imageScaling = .scaleProportionallyDown
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		return imageView
	}()

	var cellAppearance: TimelineCellAppearance!
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
			needsDisplay = true
		}
	}
	
	var isSelected = false {
		didSet {
			dateView.selected = isSelected
			feedNameView.selected = isSelected
			titleView.selected = isSelected
			needsDisplay = true
		}
	}

	private func addSubviewAtInit(_ view: NSView, hidden: Bool) {

		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isHidden = hidden
	}

	private func commonInit() {

		addSubviewAtInit(titleView, hidden: false)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(avatarImageView, hidden: true)
		addSubviewAtInit(faviconImageView, hidden: true)
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
	
	private func updatedLayoutRects() -> TimelineCellLayout {

		return timelineCellLayout(NSWidth(bounds), cellData: cellData, appearance: cellAppearance)
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
		faviconImageView.rs_setFrameIfNotEqual(layoutRects.faviconRect)
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

	private func updateTitleView() {

		titleView.attributedStringValue = cellData.attributedTitle
		needsLayout = true
	}
	
	private func updateDateView() {

		dateView.attributedStringValue = cellData.attributedDateString
		needsLayout = true
	}

	private func updateFeedNameView() {

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

	private func updateUnreadIndicator() {
		
		if unreadIndicatorView.isHidden != cellData.read {
			unreadIndicatorView.isHidden = cellData.read
		}
	}

	private func updateAvatar() {

//		if let image = cellData.avatar {
//			if avatarImageView.image !== image {
//				avatarImageView.image = image
//			}
//			avatarImageView.isHidden = false
//		}
//		else {
//			avatarImageView.isHidden = true
//		}
	}

	private func updateFavicon() {

		if let favicon = cellData.showFeedName ? cellData.favicon : nil {
			faviconImageView.image = favicon
			faviconImageView.isHidden = false
		}
		else {
			faviconImageView.image = nil
			faviconImageView.isHidden = true
		}
	}

	private func updateSubviews() {

		updateTitleView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateAvatar()
		updateFavicon()
	}
	
	private func updateAppearance() {
		
		if let rowView = superview as? NSTableRowView {
			isEmphasized = rowView.isEmphasized
			isSelected = rowView.isSelected
		}
		else {
			isEmphasized = false
			isSelected = false
		}
	}
}
