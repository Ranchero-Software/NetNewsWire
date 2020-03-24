//
//  MasterTimelineTableViewCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

class MasterTimelineTableViewCell: VibrantTableViewCell {
	
	private let titleView = MasterTimelineTableViewCell.multiLineUILabel()
	private let summaryView = MasterTimelineTableViewCell.multiLineUILabel()
	private let unreadIndicatorView = MasterUnreadIndicatorView(frame: CGRect.zero)
	private let dateView = MasterTimelineTableViewCell.singleLineUILabel()
	private let feedNameView = MasterTimelineTableViewCell.singleLineUILabel()
	
	private lazy var iconView = IconView()
	
	private lazy var starView = {
		return NonIntrinsicImageView(image: AppAssets.timelineStarImage)
	}()
	
	var cellData: MasterTimelineCellData! {
		didSet {
			updateSubviews()
		}
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}
	
	override func prepareForReuse() {
		unreadIndicatorView.isHidden = true
		starView.isHidden = true
	}
	
	override var frame: CGRect {
		didSet {
			setNeedsLayout()
		}
	}
	
	override func updateVibrancy(animated: Bool) {
		updateLabelVibrancy(titleView, color: labelColor, animated: animated)
		updateLabelVibrancy(summaryView, color: labelColor, animated: animated)
		updateLabelVibrancy(dateView, color: secondaryLabelColor, animated: animated)
		updateLabelVibrancy(feedNameView, color: secondaryLabelColor, animated: animated)
		
		UIView.animate(withDuration: duration(animated: animated)) {
			if self.isHighlighted || self.isSelected {
				self.unreadIndicatorView.backgroundColor = AppAssets.vibrantTextColor
			} else {
				self.unreadIndicatorView.backgroundColor = AppAssets.secondaryAccentColor
			}
		}
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		let layout = updatedLayout(width: size.width)
		return CGSize(width: size.width, height: layout.height)
	}

	override func layoutSubviews() {
		
		super.layoutSubviews()
		
		let layout = updatedLayout(width: bounds.width)

		unreadIndicatorView.setFrameIfNotEqual(layout.unreadIndicatorRect)
		starView.setFrameIfNotEqual(layout.starRect)
		iconView.setFrameIfNotEqual(layout.iconImageRect)
		setFrame(for: titleView, rect: layout.titleRect)
		setFrame(for: summaryView, rect: layout.summaryRect)
		feedNameView.setFrameIfNotEqual(layout.feedNameRect)
		dateView.setFrameIfNotEqual(layout.dateRect)

		separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
	}
	
	func setIconImage(_ image: IconImage) {
		iconView.iconImage = image
	}
	
}

// MARK: - Private

private extension MasterTimelineTableViewCell {
	
	static func singleLineUILabel() -> UILabel {
		let label = NonIntrinsicLabel()
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		return label
	}
	
	static func multiLineUILabel() -> UILabel {
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		return label
	}
	
	func setFrame(for label: UILabel, rect: CGRect) {
		
		if Int(floor(rect.height)) == 0 || Int(floor(rect.width)) == 0 {
			hideView(label)
		} else {
			showView(label)
			label.setFrameIfNotEqual(rect)
		}
		
	}

	func addSubviewAtInit(_ view: UIView, hidden: Bool) {
		addSubview(view)
		view.translatesAutoresizingMaskIntoConstraints = false
		view.isHidden = hidden
	}
	
	func commonInit() {
		
		addSubviewAtInit(titleView, hidden: false)
		addSubviewAtInit(summaryView, hidden: true)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(iconView, hidden: true)
		addSubviewAtInit(starView, hidden: true)
	}
	
	func updatedLayout(width: CGFloat) -> MasterTimelineCellLayout {
		if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
			return MasterTimelineAccessibilityCellLayout(width: width, insets: safeAreaInsets, cellData: cellData)
		} else {
			return MasterTimelineDefaultCellLayout(width: width, insets: safeAreaInsets, cellData: cellData)
		}
	}
	
	func updateTitleView() {
		titleView.font = MasterTimelineDefaultCellLayout.titleFont
		titleView.textColor = labelColor
		updateTextFieldText(titleView, cellData?.title)
	}
	
	func updateSummaryView() {
		summaryView.font = MasterTimelineDefaultCellLayout.summaryFont
		summaryView.textColor = labelColor
		updateTextFieldText(summaryView, cellData?.summary)
	}
	
	func updateDateView() {
		dateView.font = MasterTimelineDefaultCellLayout.dateFont
		dateView.textColor = secondaryLabelColor
		updateTextFieldText(dateView, cellData.dateString)
	}
	
	func updateTextFieldText(_ label: UILabel, _ text: String?) {
		let s = text ?? ""
		if label.text != s {
			label.text = s
			setNeedsLayout()
		}
	}
	
	func updateFeedNameView() {
		if cellData.showFeedName {
			showView(feedNameView)
			feedNameView.font = MasterTimelineDefaultCellLayout.feedNameFont
			feedNameView.textColor = secondaryLabelColor
			updateTextFieldText(feedNameView, cellData.feedName)
		} else {
			hideView(feedNameView)
		}
	}
	
	func updateUnreadIndicator() {
		if !unreadIndicatorView.isHidden && cellData.read && !cellData.starred {
			UIView.animate(withDuration: 0.66, animations: { self.unreadIndicatorView.alpha = 0 }) { _ in
				self.unreadIndicatorView.isHidden = true
				self.unreadIndicatorView.alpha = 1
			}
		} else {
			showOrHideView(unreadIndicatorView, cellData.read || cellData.starred)
		}
	}
	
	func updateStarView() {
		if !starView.isHidden &&  cellData.read && !cellData.starred {
			UIView.animate(withDuration: 0.66, animations: { self.starView.alpha = 0 }) { _ in
				self.starView.isHidden = true
				self.starView.alpha = 1
			}
		} else {
			showOrHideView(starView, !cellData.starred)
		}
	}
	
	func updateIconImage() {
		guard let image = cellData.iconImage, cellData.showIcon else {
			makeIconEmpty()
			return
		}

		showView(iconView)
		
		if iconView.iconImage !== cellData.iconImage {
			iconView.iconImage = image
			setNeedsLayout()
		}
	}
	
	func updateAccessiblityLabel() {
		accessibilityLabel = "\(cellData.feedName), \(cellData.title), \(cellData.summary), \(cellData.dateString)"
	}
	
	func makeIconEmpty() {
		if iconView.iconImage != nil {
			iconView.iconImage = nil
			setNeedsLayout()
		}
		hideView(iconView)
	}
	
	func hideView(_ view: UIView) {
		if !view.isHidden {
			view.isHidden = true
		}
	}
	
	func showView(_ view: UIView) {
		if view.isHidden {
			view.isHidden = false
		}
	}
	
	func showOrHideView(_ view: UIView, _ shouldHide: Bool) {
		shouldHide ? hideView(view) : showView(view)
	}
	
	func updateSubviews() {
		updateTitleView()
		updateSummaryView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateStarView()
		updateIconImage()
		updateAccessiblityLabel()
	}
	
}
