//
//  MasterTimelineTableViewCell.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 8/31/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import UIKit
import RSCore

class MasterTimelineTableViewCell: UITableViewCell {
	
	private let titleView = MasterTimelineTableViewCell.multiLineUILabel()
	private let summaryView = MasterTimelineTableViewCell.multiLineUILabel()
	private let unreadIndicatorView = MasterUnreadIndicatorView(frame: CGRect.zero)
	private let dateView = MasterTimelineTableViewCell.singleLineUILabel()
	private let feedNameView = MasterTimelineTableViewCell.singleLineUILabel()
	
	private var layout: MasterTimelineCellLayout?
	
	private lazy var avatarImageView: UIImageView = {
		let imageView = NonIntrinsicImageView(image: AppAssets.feedImage)
		imageView.contentMode = .scaleAspectFit
		return imageView
	}()
	
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
	
	override var frame: CGRect {
		didSet {
			setNeedsLayout()
		}
	}
	
	override func sizeThatFits(_ size: CGSize) -> CGSize {
		if layout == nil {
			layout = updatedLayout()
		}
		return CGSize(width: bounds.width, height: layout!.height)
	}

	override func layoutSubviews() {
		
		super.layoutSubviews()
		
		if layout == nil {
			layout = updatedLayout()
		}

		unreadIndicatorView.setFrameIfNotEqual(layout!.unreadIndicatorRect)
		starView.setFrameIfNotEqual(layout!.starRect)
		avatarImageView.setFrameIfNotEqual(layout!.avatarImageRect)
		setFrame(for: titleView, rect: layout!.titleRect)
		setFrame(for: summaryView, rect: layout!.summaryRect)
		feedNameView.setFrameIfNotEqual(layout!.feedNameRect)
		dateView.setFrameIfNotEqual(layout!.dateRect)

		separatorInset = layout!.separatorInsets
		
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
		label.lineBreakMode = .byWordWrapping
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
		
		theme()
		addAccessoryView()
		addSubviewAtInit(titleView, hidden: false)
		addSubviewAtInit(summaryView, hidden: true)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(avatarImageView, hidden: true)
		addSubviewAtInit(starView, hidden: true)
		
	}
	
	func theme() {
		let bgView = UIView()
		bgView.backgroundColor = AppAssets.selectionBackgroundColor
		selectedBackgroundView = bgView
	}

	func addAccessoryView() {
		accessoryView = UIImageView(image: AppAssets.chevronRightImage)
	}

	func updatedLayout() -> MasterTimelineCellLayout {
		if UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory {
			return MasterTimelineAccessibilityCellLayout(width: bounds.width, insets: safeAreaInsets, cellData: cellData)
		} else {
			return MasterTimelineDefaultCellLayout(width: bounds.width, insets: safeAreaInsets, cellData: cellData)
		}
	}
	
	func updateTitleView() {
		titleView.font = MasterTimelineDefaultCellLayout.titleFont
		titleView.textColor = MasterTimelineDefaultCellLayout.titleColor
		updateTextFieldText(titleView, cellData?.title)
	}
	
	func updateSummaryView() {
		summaryView.font = MasterTimelineDefaultCellLayout.summaryFont
		summaryView.textColor = MasterTimelineDefaultCellLayout.summaryColor
		updateTextFieldText(summaryView, cellData?.summary)
	}
	
	func updateDateView() {
		dateView.font = MasterTimelineDefaultCellLayout.dateFont
		dateView.textColor = MasterTimelineDefaultCellLayout.dateColor
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
			feedNameView.textColor = MasterTimelineDefaultCellLayout.feedColor
			updateTextFieldText(feedNameView, cellData.feedName)
		} else {
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
		
		guard let image = cellData.avatar, cellData.showAvatar else {
			makeAvatarEmpty()
			return
		}

		showView(avatarImageView)
		avatarImageView.layer.cornerRadius = MasterTimelineDefaultCellLayout.avatarCornerRadius
		avatarImageView.clipsToBounds = true
		
		if avatarImageView.image !== cellData.avatar {
			avatarImageView.image = image
			setNeedsLayout()
		}
	}
	
	func makeAvatarEmpty() {
		
		if avatarImageView.image != nil {
			avatarImageView.image = nil
			setNeedsLayout()
		}
		hideView(avatarImageView)
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
		layout = nil
		updateTitleView()
		updateSummaryView()
		updateDateView()
		updateFeedNameView()
		updateUnreadIndicator()
		updateStarView()
		updateAvatar()
	}
	
}
