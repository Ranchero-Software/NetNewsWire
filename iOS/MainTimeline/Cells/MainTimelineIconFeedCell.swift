//
//  PseudoFeedTableViewCell.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 19/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineIconFeedCell: UITableViewCell {
	@IBOutlet var articleTitle: UILabel!
	@IBOutlet var authorByLine: UILabel!
	@IBOutlet var iconView: IconView!
	@IBOutlet var indicatorView: IconView!
	@IBOutlet var articleDate: UILabel!
	@IBOutlet var metaDataStackView: UIStackView!
	@IBOutlet var separatorView: UIView!
	
	private var separatorLeadingConstraint: NSLayoutConstraint?
	private var separatorTrailingConstraint: NSLayoutConstraint?
	private var separatorTopConstraint: NSLayoutConstraint?
	private var separatorHeightConstraint: NSLayoutConstraint?
	
	private(set) var usedTitleLineCount: Int = 0
	
	var cellData: MainTimelineCellData! {
		didSet {
			configure(cellData)
		}
	}
	
	var indexPathRow: Int = 0 {
		didSet {
			configureSeparator(indexRow: indexPathRow)
		}
	}
	
	var isPreview: Bool = false
	
	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			indicatorView.alpha = 0.0
			iconView.translatesAutoresizingMaskIntoConstraints = false
			configureStackView()
			
			separatorView.translatesAutoresizingMaskIntoConstraints = false
			// Create base constraints once; we'll adjust the leading anchor per index later
			separatorTopConstraint = separatorView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0)
			separatorHeightConstraint = separatorView.heightAnchor.constraint(equalToConstant: 1)
			separatorTrailingConstraint = separatorView.trailingAnchor.constraint(equalTo: articleTitle.trailingAnchor)
			// Leading constraint will be configured in configureSeparator(indexRow:)
			NSLayoutConstraint.activate([
				separatorTopConstraint!,
				separatorHeightConstraint!,
				separatorTrailingConstraint!
			])
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
		applyTitleTextWithAttributes(configurationState)
		articleTitle.setNeedsLayout()
		articleTitle.layoutIfNeeded()
	}
	
	private func configureStackView() {
		switch traitCollection.preferredContentSizeCategory {
		case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
			metaDataStackView.axis = .vertical
			metaDataStackView.alignment = .leading
			metaDataStackView.distribution = .fill
		default:
			metaDataStackView.axis = .horizontal
			metaDataStackView.alignment = .center
			metaDataStackView.distribution = .fill
		}
	}
	
	private func configure(_ cellData: MainTimelineCellData) {
		updateIndicatorView(cellData)
		articleTitle.numberOfLines = cellData.numberOfLines
		
		if cellData.showFeedName == .feed {
			authorByLine.text = cellData.feedName
		} else if cellData.showFeedName == .byline {
			authorByLine.text = cellData.byline
		} else if cellData.showFeedName == .none {
			authorByLine.text = ""
		}
		
		setIconImage(cellData.iconImage, with: cellData.iconSize)
		
		articleDate.text = cellData.dateString
	}
	
	private func configureSeparator(indexRow: Int) {
		// Set base constraints if they don't exist.
		if separatorTopConstraint == nil || separatorHeightConstraint == nil || separatorTrailingConstraint == nil {
			separatorView.translatesAutoresizingMaskIntoConstraints = false
			separatorTopConstraint = separatorView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 0)
			separatorHeightConstraint = separatorView.heightAnchor.constraint(equalToConstant: 1)
			separatorTrailingConstraint = separatorView.trailingAnchor.constraint(equalTo: articleTitle.trailingAnchor)
			NSLayoutConstraint.activate([
				separatorTopConstraint!,
				separatorHeightConstraint!,
				separatorTrailingConstraint!
			])
		}

		// disable leading constraints
		if let existingLeading = separatorLeadingConstraint {
			existingLeading.isActive = false
			separatorLeadingConstraint = nil
		}

		// Give initial row special treatment
		if indexRow == 0 {
			separatorLeadingConstraint = separatorView.leadingAnchor.constraint(equalTo: indicatorView.leadingAnchor)
		} else {
			separatorLeadingConstraint = separatorView.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8)
		}

		separatorLeadingConstraint?.isActive = true

		setNeedsLayout()
		layoutIfNeeded()
	}
	
	private func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
		iconView.iconImage = iconImage
		updateIconViewSizeConstraints(to: size.size)
	}
	
	func setIconImage(_ iconImage: IconImage?) {
		if iconView.iconImage !== iconImage {
			iconView.iconImage = iconImage
		}
	}
	
	private func updateIconViewSizeConstraints(to size: CGSize) {
		for constraint in iconView.constraints {
			constraint.isActive = false
		}
		
		NSLayoutConstraint.activate([
			iconView.widthAnchor.constraint(equalToConstant: size.width),
			iconView.heightAnchor.constraint(equalToConstant: size.height)
		])
		
		setNeedsLayout()
	}
	
	private func updateIndicatorView(_ cellData: MainTimelineCellData) {
		if cellData.read == false {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
				self.indicatorView.tintColor = Assets.Colors.secondaryAccent
			}
			return
		} else if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = Assets.Colors.star
			}
			return
		} else if indicatorView.alpha == 1.0 {
			UIView.animate(withDuration: 0.25) {
				self.indicatorView.alpha = 0.0
				self.indicatorView.iconImage = nil
			}
		}
	}
	
	private func applyTitleTextWithAttributes(_ state: UICellConfigurationState) {
		let attributedCellText = NSMutableAttributedString()
		if cellData.title != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .headline).lineHeight
			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .headline),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: titleTextColor(for: state)
			]
			let titleAttributed = NSAttributedString(string: cellData.title, attributes: titleAttributes)
			attributedCellText.append(titleAttributed)
		}
		
		articleTitle.attributedText = attributedCellText
		
		if linesUsedForTitleGreaterThanOrEqualToPreference() {
			articleTitle.lineBreakMode = .byWordWrapping
			return
		}
		
		if cellData.summary != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).lineHeight
			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .body),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: titleTextColor(for: state)
			]
			var summaryAttributed: NSAttributedString
			if cellData.title != "" {
				summaryAttributed = NSAttributedString(string: "\n" + cellData.summary, attributes: summaryAttributes)
			} else {
				summaryAttributed = NSAttributedString(string: cellData.summary, attributes: summaryAttributes)
			}
			attributedCellText.append(summaryAttributed)
		}
	
		articleTitle.attributedText = attributedCellText
		articleTitle.lineBreakMode = .byTruncatingTail
	}
	
	private func linesUsedForTitleGreaterThanOrEqualToPreference() -> Bool {
		let attributed = articleTitle.attributedText ?? NSAttributedString()
		let textStorage = NSTextStorage(attributedString: attributed)
		let containerSize = CGSize(width: articleTitle.bounds.width, height: .greatestFiniteMagnitude)
		let textContainer = NSTextContainer(size: containerSize)
		textContainer.lineFragmentPadding = 0
		textContainer.maximumNumberOfLines = articleTitle.numberOfLines // 0 means unlimited
		textContainer.lineBreakMode = articleTitle.lineBreakMode

		let layoutManager = NSLayoutManager()
		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)

		_ = layoutManager.glyphRange(for: textContainer)

		var lineCount = 0
		var glyphIndex = 0
		let glyphs = layoutManager.numberOfGlyphs
		while glyphIndex < glyphs {
			var lineRange = NSRange()
			_ = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: &lineRange)
			glyphIndex = NSMaxRange(lineRange)
			lineCount += 1
		}
		usedTitleLineCount = lineCount
		return usedTitleLineCount == AppDefaults.shared.timelineNumberOfLines
	}
	
	func titleTextColor(for state: UICellConfigurationState) -> UIColor {
		let isSelected = state.isSelected || state.isHighlighted || state.isEditing || state.isSwiped
		if isSelected {
			return .white
		} else {
			return .label
		}
	}
	
	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)
		
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		backgroundConfig.cornerRadius = 20
		if traitCollection.userInterfaceIdiom == .pad {
			backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
			backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: !isPreview ? -4 : -12, bottom: 0, trailing: !isPreview ? -4 : -12)
		}
		
		let isActive = state.isSelected || state.isHighlighted || state.isEditing || state.isSwiped
		
		if isActive {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			articleTitle.textColor = titleTextColor(for: state)
			articleDate.textColor = .lightText
			authorByLine.textColor = .lightText
		} else {
			articleTitle.textColor = titleTextColor(for: state)
			articleDate.textColor = .secondaryLabel
			authorByLine.textColor = .secondaryLabel
		}
		
		self.backgroundConfiguration = backgroundConfig
		
	}
	
}
