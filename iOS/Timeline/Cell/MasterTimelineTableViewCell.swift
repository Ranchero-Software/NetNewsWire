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
	private let summaryView = MasterTimelineTableViewCell.singleLineUILabel()
	private let textView = MasterTimelineTableViewCell.multiLineUILabel()
	private let unreadIndicatorView = MasterUnreadIndicatorView(frame: CGRect.zero)
	private let dateView = MasterTimelineTableViewCell.singleLineUILabel()
	private let feedNameView = MasterTimelineTableViewCell.singleLineUILabel()
	
	private lazy var avatarImageView = {
		return UIImageView(image: AppAssets.feedImage)
	}()
	
	private lazy var starView = {
		return UIImageView(image: AppAssets.timelineStarImage)
	}()
	
	private lazy var textFields = {
		return [self.dateView, self.feedNameView, self.titleView, self.summaryView, self.textView]
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
	
	override func layoutSubviews() {
		
		super.layoutSubviews()
		
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

private extension MasterTimelineTableViewCell {
	
	static func singleLineUILabel() -> UILabel {
		let label = UILabel()
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		return label
	}
	
	static func multiLineUILabel() -> UILabel {
		let label = UILabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byWordWrapping
		label.allowsDefaultTighteningForTruncation = false
		return label
	}
	
	func setFrame(for label: UILabel, rect: CGRect) {
		
		if Int(floor(rect.height)) == 0 || Int(floor(rect.width)) == 0 {
			hideView(label)
		} else {
			showView(label)
			label.rs_setFrameIfNotEqual(rect)
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
		addSubviewAtInit(textView, hidden: true)
		addSubviewAtInit(unreadIndicatorView, hidden: true)
		addSubviewAtInit(dateView, hidden: false)
		addSubviewAtInit(feedNameView, hidden: true)
		addSubviewAtInit(avatarImageView, hidden: true)
		addSubviewAtInit(starView, hidden: true)
		
	}
	
	func updatedLayoutRects() -> MasterTimelineCellLayout {
		
		return MasterTimelineCellLayout(width: bounds.width, height: bounds.height, cellData: cellData, hasAvatar: avatarImageView.image != nil)
	}
	
	func updateTitleView() {
		titleView.font = MasterTimelineCellLayout.titleFont
		titleView.textColor = MasterTimelineCellLayout.titleColor
		updateTextFieldText(titleView, cellData?.title)
	}
	
	func updateSummaryView() {
		summaryView.font = MasterTimelineCellLayout.textFont
		summaryView.textColor = MasterTimelineCellLayout.textColor
		updateTextFieldText(summaryView, cellData?.text)
	}
	
	func updateTextView() {
		textView.font = MasterTimelineCellLayout.textFont
		textView.textColor = MasterTimelineCellLayout.textColor
		updateTextFieldText(textView, cellData?.text)
	}
	
	func updateDateView() {
		dateView.font = MasterTimelineCellLayout.dateFont
		dateView.textColor = MasterTimelineCellLayout.dateColor
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
			feedNameView.font = MasterTimelineCellLayout.feedNameFont
			feedNameView.textColor = MasterTimelineCellLayout.feedColor
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
		
		// The avatar should be bigger than a favicon. They’re too small; they look weird.
		guard let image = cellData.avatar, cellData.showAvatar, image.size.height >= 22.0, image.size.width >= 22.0 else {
			makeAvatarEmpty()
			return
		}

		showView(avatarImageView)
		avatarImageView.layer.cornerRadius = MasterTimelineCellLayout.avatarCornerRadius
		avatarImageView.clipsToBounds = true
		
		if avatarImageView.image !== image {
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
