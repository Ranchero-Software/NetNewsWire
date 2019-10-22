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
	
	private lazy var avatarView = MasterTimelineAvatarView()
	
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
	
	override func applyThemeProperties() {
		super.applyThemeProperties()

		let highlightedTextColor = AppAssets.vibrantTextColor
		
		titleView.highlightedTextColor = highlightedTextColor
		summaryView.highlightedTextColor = highlightedTextColor
		dateView.highlightedTextColor = highlightedTextColor
		feedNameView.highlightedTextColor = highlightedTextColor
	}
	
	override var frame: CGRect {
		didSet {
			setNeedsLayout()
		}
	}
	
	override func setHighlighted(_ highlighted: Bool, animated: Bool) {
		super.setHighlighted(highlighted, animated: animated)
		unreadIndicatorView.isSelected = isHighlighted || isSelected
	}

	override func setSelected(_ selected: Bool, animated: Bool) {
		super.setSelected(selected, animated: animated)
		unreadIndicatorView.isSelected = isHighlighted || isSelected
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
		avatarView.setFrameIfNotEqual(layout.avatarImageRect)
		setFrame(for: titleView, rect: layout.titleRect)
		setFrame(for: summaryView, rect: layout.summaryRect)
		feedNameView.setFrameIfNotEqual(layout.feedNameRect)
		dateView.setFrameIfNotEqual(layout.dateRect)

		separatorInset = layout.separatorInsets
		
	}
	
	func setAvatarImage(_ image: UIImage) {
		avatarView.image = image
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
		addSubviewAtInit(avatarView, hidden: true)
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
		titleView.textColor = .label
		updateTextFieldText(titleView, cellData?.title)
	}
	
	func updateSummaryView() {
		summaryView.font = MasterTimelineDefaultCellLayout.summaryFont
		summaryView.textColor = .label
		updateTextFieldText(summaryView, cellData?.summary)
	}
	
	func updateDateView() {
		dateView.font = MasterTimelineDefaultCellLayout.dateFont
		dateView.textColor = .secondaryLabel
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
			feedNameView.textColor = .secondaryLabel
			updateTextFieldText(feedNameView, cellData.feedName)
		} else {
			hideView(feedNameView)
		}
	}
	
	func updateUnreadIndicator() {
		let hide = cellData.read || cellData.starred
		self.unreadIndicatorView.isHidden = hide
		self.unreadIndicatorView.frame.size = !hide ? CGSize.zero : MasterTimelineDefaultCellLayout.unreadCircleSize
		UIView.animate(
			withDuration: 0.5,
			delay: 0.0,
			usingSpringWithDamping: 0.5,
			initialSpringVelocity: 0.2,
			animations: {
				self.unreadIndicatorView.frame.size = !hide ? MasterTimelineDefaultCellLayout.unreadCircleSize : CGSize.zero
			})
	}
	
	func updateStarView() {
		self.starView.isHidden = !self.cellData.starred
		self.starView.frame.size = self.cellData.starred ? CGSize.zero : MasterTimelineDefaultCellLayout.starSize
		UIView.animate(
			withDuration: 0.5,
			delay: 0.0,
			usingSpringWithDamping: 0.5,
			initialSpringVelocity: 0.2,
			animations: {
				self.starView.frame.size = self.cellData.starred ? MasterTimelineDefaultCellLayout.starSize : CGSize.zero
			})
	}
	
	func updateAvatar() {
		
		guard let image = cellData.avatar, cellData.showAvatar else {
			makeAvatarEmpty()
			return
		}

		showView(avatarView)
		avatarView.layer.cornerRadius = MasterTimelineDefaultCellLayout.avatarCornerRadius
		avatarView.clipsToBounds = true
		
		if avatarView.image !== cellData.avatar {
			avatarView.image = image
			setNeedsLayout()
		}
	}
	
	func makeAvatarEmpty() {
		
		if avatarView.image != nil {
			avatarView.image = nil
			setNeedsLayout()
		}
		hideView(avatarView)
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
	
	func updateSubviews() {
		updateTitleView()
		updateSummaryView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateStarView()
		updateAvatar()
	}
	
}
