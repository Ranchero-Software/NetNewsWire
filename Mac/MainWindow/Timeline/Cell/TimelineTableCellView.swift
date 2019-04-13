//
//  TimelineTableCellView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import RSCore

class TimelineTableCellView: NSTableCellView {

	private let titleView = TimelineTableCellView.multiLineTextField()
	private let summaryView = TimelineTableCellView.singleLineTextField()
	private let textView = TimelineTableCellView.multiLineTextField()
	private let unreadIndicatorView = UnreadIndicatorView(frame: NSZeroRect)
	private let dateView = TimelineTableCellView.singleLineTextField()
	private let feedNameView = TimelineTableCellView.singleLineTextField()

	private lazy var avatarImageView: NSImageView = {
		let imageView = TimelineTableCellView.imageView(with: AppImages.genericFeedImage, scaling: .scaleProportionallyDown)
		imageView.wantsLayer = true
		return imageView
	}()

	private let starView = TimelineTableCellView.imageView(with: AppImages.timelineStar, scaling: .scaleNone)

	private lazy var textFields = {
		return [self.dateView, self.feedNameView, self.titleView, self.summaryView, self.textView]
	}()

	var cellAppearance: TimelineCellAppearance! {
		didSet {
			if cellAppearance != oldValue {
				updateTextFieldFonts()
				avatarImageView.layer?.cornerRadius = cellAppearance.avatarCornerRadius
				needsLayout = true
			}
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

	override init(frame frameRect: NSRect) {
		super.init(frame: frameRect)
		commonInit()
	}
	
	required init?(coder: NSCoder) {		
		super.init(coder: coder)
		commonInit()
	}

	convenience init() {
		self.init(frame: NSRect.zero)
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
	}
	
	override func layout() {

		resizeSubviews(withOldSize: NSZeroSize)
	}
	
	override func resizeSubviews(withOldSize oldSize: NSSize) {
		
		let layoutRects = updatedLayoutRects()

		setFrame(for: titleView, rect: layoutRects.titleRect)
		setFrame(for: summaryView, rect: layoutRects.summaryRect)
		setFrame(for: textView, rect: layoutRects.textRect)

		dateView.rs_setFrameIfNotEqual(layoutRects.dateRect)
		unreadIndicatorView.rs_setFrameIfNotEqual(layoutRects.unreadIndicatorRect)
		feedNameView.rs_setFrameIfNotEqual(layoutRects.feedNameRect)
		avatarImageView.rs_setFrameIfNotEqual(layoutRects.avatarImageRect)
		starView.rs_setFrameIfNotEqual(layoutRects.starRect)
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
		textField.allowsDefaultTighteningForTruncation = false
		return textField
	}

	static func multiLineTextField() -> NSTextField {

		let textField = NSTextField(wrappingLabelWithString: "")
		textField.usesSingleLineMode = false
		textField.maximumNumberOfLines = 2
		textField.isEditable = false
		textField.cell?.truncatesLastVisibleLine = true
		textField.allowsDefaultTighteningForTruncation = false
		return textField
	}

	static func imageView(with image: NSImage?, scaling: NSImageScaling) -> NSImageView {

		let imageView = image != nil ? NSImageView(image: image!) : NSImageView(frame: NSRect.zero)
		imageView.animates = false
		imageView.imageAlignment = .alignCenter
		imageView.imageScaling = scaling
		return imageView
	}

	func setFrame(for textField: NSTextField, rect: NSRect) {

		if Int(floor(rect.height)) == 0 || Int(floor(rect.width)) == 0 {
			hideView(textField)
		}
		else {
			showView(textField)
			textField.rs_setFrameIfNotEqual(rect)
		}
	}

	func makeTextFieldColorsNormal() {
		titleView.textColor = NSColor.labelColor
		feedNameView.textColor = NSColor.secondaryLabelColor
		dateView.textColor = NSColor.secondaryLabelColor
		summaryView.textColor = NSColor.secondaryLabelColor
		textView.textColor = NSColor.labelColor
	}

	func updateTextFieldFonts() {

		feedNameView.font = cellAppearance.feedNameFont
		dateView.font = cellAppearance.dateFont
		titleView.font = cellAppearance.titleFont
		summaryView.font = cellAppearance.textFont
		textView.font = cellAppearance.textOnlyFont
	}

	func addSubviewAtInit(_ view: NSView, hidden: Bool) {

		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isHidden = hidden
	}

	func commonInit() {
		addSubviewAtInit(titleView, hidden: false)
		addSubviewAtInit(summaryView, hidden: true)
		addSubviewAtInit(textView, hidden: true)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(avatarImageView, hidden: true)
		addSubviewAtInit(starView, hidden: true)

		makeTextFieldColorsNormal()
	}

	func updatedLayoutRects() -> TimelineCellLayout {

		return TimelineCellLayout(width: bounds.width, height: bounds.height, cellData: cellData, appearance: cellAppearance, hasAvatar: avatarImageView.image != nil)
	}

	func updateTitleView() {

		updateTextFieldText(titleView, cellData?.title)
	}

	func updateSummaryView() {

		updateTextFieldText(summaryView, cellData?.text)
	}

	func updateTextView() {

		updateTextFieldText(textView, cellData?.text)
	}

	func updateDateView() {

		updateTextFieldText(dateView, cellData.dateString)
	}

	func updateTextFieldText(_ textField: NSTextField, _ text: String?) {

		let s = text ?? ""
		if textField.stringValue != s {
			textField.stringValue = s
			needsLayout = true
		}
	}

	func updateFeedNameView() {

		if cellData.showFeedName {
			showView(feedNameView)
			updateTextFieldText(feedNameView, cellData.feedName)
		}
		else {
			hideView(feedNameView)
		}
	}

	func updateUnreadIndicator() {

		showOrHideView(unreadIndicatorView, cellData.read || cellData.starred)
	}

	func updateStarView() {

		showOrHideView(starView, !cellData.starred)
	}

	func updateAvatar() {

		// The avatar should be bigger than a favicon. They’re too small; they look weird.
		guard let image = cellData.avatar, cellData.showAvatar, image.size.height >= 22.0, image.size.width >= 22.0 else {
			makeAvatarEmpty()
			return
		}

		showView(avatarImageView)
		if avatarImageView.image !== image {
			avatarImageView.image = image
			needsLayout = true
		}
	}

	func makeAvatarEmpty() {

		if avatarImageView.image != nil {
			avatarImageView.image = nil
			needsLayout = true
		}
		hideView(avatarImageView)
	}

	func hideView(_ view: NSView) {

		if !view.isHidden {
			view.isHidden = true
		}
	}

	func showView(_ view: NSView) {

		if view.isHidden {
			view.isHidden = false
		}
	}

	func showOrHideView(_ view: NSView, _ shouldHide: Bool) {

		shouldHide ? hideView(view) : showView(view)
	}

	func updateSubviews() {
		updateTitleView()
		updateSummaryView()
		updateTextView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateStarView()
		updateAvatar()
	}
}
