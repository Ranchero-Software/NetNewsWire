//
//  TimelineTableCellView.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import AppKit
import RSCore

class TimelineTableCellView: NSTableCellView {

	private let titleView = TimelineTableCellView.multiLineTextField()
	private let summaryView = TimelineTableCellView.multiLineTextField()
	private let textView = TimelineTableCellView.multiLineTextField()
	private let unreadIndicatorView = UnreadIndicatorView(frame: NSZeroRect)
	private let dateView = TimelineTableCellView.singleLineTextField()
	private let feedNameView = TimelineTableCellView.singleLineTextField()

	private lazy var iconView = IconView()

	private var starView = TimelineTableCellView.imageView(with: AppAssets.timelineStarUnselected, scaling: .scaleNone)

	private lazy var textFields = {
		return [self.dateView, self.feedNameView, self.titleView, self.summaryView, self.textView]
	}()

	var cellAppearance: TimelineCellAppearance! {
		didSet {
			if cellAppearance != oldValue {
				updateTextFieldFonts()
				iconView.layer?.cornerRadius = cellAppearance.iconCornerRadius
				needsLayout = true
			}
		}
	}
	
	var cellData: TimelineCellData! {
		didSet {
			updateSubviews()
		}
	}
	
	var isEmphasized: Bool = false {
		didSet {
			unreadIndicatorView.isEmphasized = isEmphasized
			updateStarView()
		}
	}

	var isSelected: Bool = false {
		didSet {
			unreadIndicatorView.isSelected = isSelected
			updateStarView()
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

		dateView.setFrame(ifNotEqualTo: layoutRects.dateRect)
		unreadIndicatorView.setFrame(ifNotEqualTo: layoutRects.unreadIndicatorRect)
		feedNameView.setFrame(ifNotEqualTo: layoutRects.feedNameRect)
		iconView.setFrame(ifNotEqualTo: layoutRects.iconImageRect)
		starView.setFrame(ifNotEqualTo: layoutRects.starRect)
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
		textField.maximumNumberOfLines = 0
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
			textField.setFrame(ifNotEqualTo: rect)
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
		addSubviewAtInit(iconView, hidden: true)
		addSubviewAtInit(starView, hidden: true)

		makeTextFieldColorsNormal()
	}

	func updatedLayoutRects() -> TimelineCellLayout {

		return TimelineCellLayout(width: bounds.width, height: bounds.height, cellData: cellData, appearance: cellAppearance, hasIcon: iconView.iconImage != nil)
	}

	func updateTitleView() {

		updateTextFieldText(titleView, cellData?.title)
		updateTextFieldAttributedText(titleView, cellData?.attributedTitle)
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

	func updateTextFieldAttributedText(_ textField: NSTextField, _ text: NSAttributedString?) {
		var s = text ?? NSAttributedString(string: "")

		if let fieldFont = textField.font {
			s = s.adding(font: fieldFont)
		}

		if textField.attributedStringValue != s {
			textField.attributedStringValue = s
			needsLayout = true
		}

		if cellData.read {
			textField.textColor = NSColor.secondaryLabelColor
		} else {
			textField.textColor = NSColor.labelColor
		}
	}

	func updateFeedNameView() {
		switch cellData.showFeedName {
		case .byline:
			showView(feedNameView)
			updateTextFieldText(feedNameView, cellData.byline)
		case .feed:
			showView(feedNameView)
			updateTextFieldText(feedNameView, cellData.feedName)
		case .none:
			hideView(feedNameView)
		}
	}

	func updateUnreadIndicator() {
		showOrHideView(unreadIndicatorView, cellData.read || cellData.starred)
	}

	func updateStarView() {
		if isSelected && isEmphasized {
			starView.image = AppAssets.timelineStarSelected
		} else {
			starView.image = AppAssets.timelineStarUnselected
		}
		showOrHideView(starView, !cellData.starred)
	}

	func updateIcon() {
		guard let iconImage = cellData.iconImage, cellData.showIcon else {
			makeIconEmpty()
			return
		}

		showView(iconView)
		if iconView.iconImage !== iconImage {
			iconView.iconImage = iconImage
			needsLayout = true
		}
	}

	func makeIconEmpty() {
		if iconView.iconImage != nil {
			iconView.iconImage = nil
			needsLayout = true
		}
		hideView(iconView)
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
		updateIcon()
	}
}
