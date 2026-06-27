//
//  MainTimelineCell.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 6/22/26.
//

import UIKit
import RSCore
import Images

///  Manual-layout timeline cell modeled on the Mac timeline
///  and the pre-7.0 iOS table view cell.
final class MainTimelineCell: UICollectionViewCell {

	static let reuseIdentifier = "MainTimelineCell"

	var isPreview = false

	private let titleView = MainTimelineCell.multiLineLabel()
	private let summaryView = MainTimelineCell.multiLineLabel()
	private let dateView = MainTimelineCell.singleLineLabel()
	private let feedNameView = MainTimelineCell.singleLineLabel()
	private lazy var iconView = IconView()
	private lazy var indicatorView = IconView()
	private let topSeparator = UIView()

	var cellData: MainTimelineCellData! {
		didSet {
			updateSubviews()
		}
	}

	override init(frame: CGRect) {
		super.init(frame: frame)
		commonInit()
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
		commonInit()
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		indicatorView.isHidden = true
	}

	override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
		let layout = updatedLayout(width: layoutAttributes.frame.width)
		layoutAttributes.frame.size.height = layout.height
		return layoutAttributes
	}

	override func layoutSubviews() {
		super.layoutSubviews()

		let layout = updatedLayout(width: contentView.bounds.width)

		setFrame(for: titleView, rect: layout.titleRect)
		setFrame(for: summaryView, rect: layout.summaryRect)
		feedNameView.setFrameIfNotEqual(layout.feedNameRect)
		dateView.setFrameIfNotEqual(layout.dateRect)
		iconView.setFrameIfNotEqual(layout.iconImageRect)
		indicatorView.setFrameIfNotEqual(cellData.starred ? layout.starRect : layout.unreadIndicatorRect)
		topSeparator.frame = CGRect(x: layout.separatorRect.minX, y: 0, width: layout.separatorRect.width, height: 1.0 / traitCollection.displayScale)
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)

		var backgroundConfig: UIBackgroundConfiguration
		if #available(iOS 18, *) {
			backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		} else {
			backgroundConfig = UIBackgroundConfiguration.listGroupedCell().updated(for: state)
		}
		if #available(iOS 26, *) {
			backgroundConfig.cornerRadius = 20
			backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
			if UIDevice.current.userInterfaceIdiom == .pad {
				backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8)
			} else if isPreview {
				backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16)
			} else {
				backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -12, bottom: 0, trailing: -12)
			}
		} else {
			backgroundConfig.cornerRadius = 0
		}

		if state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
		} else if state.isSwiped {
			backgroundConfig.backgroundColor = .secondarySystemFill
		} else {
			backgroundConfig.backgroundColor = .clear
		}

		let isActive = state.isSwiped || state.isSelected

		if isPreview {
			backgroundConfig.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
		}
		backgroundConfiguration = backgroundConfig

		topSeparator.alpha = (isActive || isPreview) ? 0.0 : 1.0

		// White foreground is only for the selected state (blue accent background).
		// The swiped state uses a subtle gray fill, so it keeps normal label colors.
		updateColors(active: state.isSelected)
		updateIndicatorView(active: state.isSelected)
	}

	func setIconImage(_ image: IconImage) {
		iconView.iconImage = image
	}
}

// MARK: - Private

private extension MainTimelineCell {

	static func singleLineLabel() -> UILabel {
		let label = NonIntrinsicLabel()
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		return label
	}

	static func multiLineLabel() -> UILabel {
		let label = NonIntrinsicLabel()
		label.numberOfLines = 0
		label.lineBreakMode = .byTruncatingTail
		label.allowsDefaultTighteningForTruncation = false
		label.adjustsFontForContentSizeCategory = true
		return label
	}

	func commonInit() {
		isAccessibilityElement = true
		topSeparator.backgroundColor = .separator.withAlphaComponent(0.1)
		for view in [titleView, summaryView, dateView, feedNameView, iconView, indicatorView, topSeparator] {
			contentView.addSubview(view)
			view.isAccessibilityElement = false
		}
		indicatorView.isHidden = true
	}

	func updatedLayout(width: CGFloat) -> MainTimelineCellLayout {
		guard cellData != nil else {
			return MainTimelineDefaultCellLayout(width: width, insets: .zero, cellData: MainTimelineCellData())
		}
		if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
			return MainTimelineAccessibilityCellLayout(width: width, insets: .zero, cellData: cellData)
		}
		return MainTimelineDefaultCellLayout(width: width, insets: .zero, cellData: cellData)
	}

	func setFrame(for label: UILabel, rect: CGRect) {
		if Int(floor(rect.height)) == 0 || Int(floor(rect.width)) == 0 {
			label.isHidden = true
		} else {
			label.isHidden = false
			label.setFrameIfNotEqual(rect)
		}
	}

	func updateSubviews() {
		titleView.font = MainTimelineDefaultCellLayout.titleFont
		titleView.attributedText = cellData.attributedTitle.applyingBaseFont(MainTimelineDefaultCellLayout.titleFont)

		summaryView.font = MainTimelineDefaultCellLayout.summaryFont
		summaryView.text = cellData.summary

		dateView.font = MainTimelineDefaultCellLayout.dateFont
		dateView.text = cellData.dateString

		switch cellData.showFeedName {
		case .feed:
			feedNameView.font = MainTimelineDefaultCellLayout.feedNameFont
			feedNameView.text = cellData.feedName
			feedNameView.isHidden = false
		case .byline:
			feedNameView.font = MainTimelineDefaultCellLayout.feedNameFont
			feedNameView.text = cellData.byline
			feedNameView.isHidden = false
		case .none:
			feedNameView.isHidden = true
		}

		if cellData.showIcon, let iconImage = cellData.iconImage {
			iconView.iconImage = iconImage
			iconView.isHidden = false
		} else {
			iconView.iconImage = nil
			iconView.isHidden = true
		}

		updateColors(active: configurationState.isSelected)
		updateIndicatorView(active: configurationState.isSelected)
		updateAccessibilityLabel()
		setNeedsLayout()
	}

	func updateColors(active: Bool) {
		titleView.textColor = active ? .white : .label
		summaryView.textColor = active ? .white : (cellData.title.isEmpty ? .label : .secondaryLabel)
		dateView.textColor = active ? .white : .secondaryLabel
		feedNameView.textColor = active ? .white : .secondaryLabel
	}

	func updateIndicatorView(active: Bool) {
		guard cellData != nil else {
			indicatorView.isHidden = true
			return
		}
		if cellData.starred {
			indicatorView.iconImage = Assets.Images.starredFeed
			indicatorView.tintColor = active ? .white : Assets.Colors.star
			indicatorView.isHidden = false
		} else if !cellData.read {
			indicatorView.iconImage = Assets.Images.unreadCellIndicator
			indicatorView.tintColor = active ? .white : Assets.Colors.secondaryAccent
			indicatorView.isHidden = false
		} else {
			indicatorView.isHidden = true
		}
	}

	func updateAccessibilityLabel() {
		let starredStatus = cellData.starred ? "\(NSLocalizedString("Starred", comment: "Starred")), " : ""
		let unreadStatus = cellData.read ? "" : "\(NSLocalizedString("Unread", comment: "Unread")), "
		accessibilityLabel = starredStatus + unreadStatus + "\(cellData.feedName), \(cellData.title), \(cellData.summary), \(cellData.dateString)"
	}
}
