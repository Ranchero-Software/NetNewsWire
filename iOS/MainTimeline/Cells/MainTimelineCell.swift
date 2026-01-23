//
//  MainTimelineCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

final class MainTimelineCell: UITableViewCell {
	@IBOutlet var articleContent: UILabel!
	@IBOutlet var articleByLine: UILabel!
	@IBOutlet var feedIcon: IconView?
	@IBOutlet var indicatorView: IconView!
	@IBOutlet var articleDate: UILabel!
	@IBOutlet var metaDataStackView: UIStackView!

	var cellData: MainTimelineCellData! {
		didSet {
			configure(cellData)
		}
	}

	var isPreview: Bool = false

	private static let indicatorAnimationDuration = 0.25

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			indicatorView.alpha = 0.0
			feedIcon?.translatesAutoresizingMaskIntoConstraints = false
			configureStackView()
		}
	}

	func setIconImage(_ iconImage: IconImage?) {
		guard let feedIcon else {
			return
		}
		if feedIcon.iconImage !== iconImage {
			feedIcon.iconImage = iconImage
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

		articleContent.textColor = titleTextColor(for: state)
		if isActive(state) {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			articleDate.textColor = .lightText
			articleByLine.textColor = .lightText
		} else {
			articleDate.textColor = .secondaryLabel
			articleByLine.textColor = .secondaryLabel
		}

		updateIndicatorView(state)

		backgroundConfiguration = backgroundConfig
	}
}

private extension MainTimelineCell {
	func configure(_ cellData: MainTimelineCellData) {
		articleContent.numberOfLines = cellData.numberOfLines
		addArticleContent(configurationState)

		switch cellData.showFeedName {
		case .feed:
			articleByLine.text = cellData.feedName
		case .byline:
			articleByLine.text = cellData.byline
		case .none:
			articleByLine.text = ""
		}

		setIconImage(cellData.iconImage, with: cellData.iconSize)

		articleDate.text = cellData.dateString
	}

	func updateIndicatorView(_ state: UICellConfigurationState) {
		if cellData.read == false {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
				self.indicatorView.tintColor = self.isActive(state) ? .white : Assets.Colors.secondaryAccent
			}
			return
		} else if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = self.isActive(state) ? .white : Assets.Colors.star
			}
			return
		} else if indicatorView.alpha == 1.0 {
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.alpha = 0.0
				self.indicatorView.iconImage = nil
			}
		}
	}

	func configureStackView() {
		switch traitCollection.preferredContentSizeCategory {
		case .accessibilityMedium, .accessibilityLarge, .accessibilityExtraLarge, .accessibilityExtraExtraLarge, .accessibilityExtraExtraExtraLarge:
			metaDataStackView.axis = .vertical
			metaDataStackView.alignment = .leading
			metaDataStackView.distribution = .fill
		default:
			metaDataStackView.axis = .horizontal
			metaDataStackView.alignment = .bottom
			metaDataStackView.distribution = .fillEqually
		}
	}

	func isActive(_ state: UICellConfigurationState) -> Bool {
		state.isSwiped || state.isSelected || state.isEditing || state.isHighlighted
	}

	func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
		setIconImage(iconImage)
		updateIconViewSizeConstraints(to: size.size)
	}

	func updateIconViewSizeConstraints(to size: CGSize) {
		guard let feedIcon else {
			return
		}

		for constraint in feedIcon.constraints {
			constraint.isActive = false
		}

		NSLayoutConstraint.activate([
			feedIcon.widthAnchor.constraint(equalToConstant: size.width),
			feedIcon.heightAnchor.constraint(equalToConstant: size.height)
		])

		setNeedsLayout()
	}

	func paragraphStyle(lineHeight: CGFloat) -> NSParagraphStyle {
		let paragraphStyle = NSMutableParagraphStyle()

		paragraphStyle.minimumLineHeight = lineHeight
		paragraphStyle.maximumLineHeight = lineHeight
		paragraphStyle.lineBreakMode = .byWordWrapping
		paragraphStyle.lineBreakStrategy = []
		paragraphStyle.hyphenationFactor = 1.0
		paragraphStyle.allowsDefaultTighteningForTruncation = true

		return paragraphStyle
	}

	func attributes(textStyle: UIFont.TextStyle, color: UIColor) -> [NSAttributedString.Key: Any] {
		let font = UIFont.preferredFont(forTextStyle: textStyle)
		let paragraphStyle = paragraphStyle(lineHeight: font.lineHeight)
		return [.font: font, .paragraphStyle: paragraphStyle, .foregroundColor: color]
	}

	func addArticleContent(_ state: UICellConfigurationState) {
		let attributedCellText = NSMutableAttributedString()

		// 1. Prepare Title
		if !cellData.title.isEmpty {
			let titleAttributes = attributes(textStyle: .headline, color: titleTextColor(for: state))
			let titleAttributed = NSAttributedString(string: cellData.title, attributes: titleAttributes)

			// 2. Measure Title Height
			let linesUsed = countLines(of: titleAttributed, width: articleContent.bounds.width)
			if linesUsed >= cellData.numberOfLines {
				// The title already fills numberOfLines lines, set it and exit
				articleContent.attributedText = titleAttributed
				articleContent.lineBreakMode = .byTruncatingTail
				return
			}

			attributedCellText.append(titleAttributed)
		}

		// 3. Prepare Summary (only reached if title < numberOfLines lines)
		if !cellData.summary.isEmpty {
			let summaryAttributes = attributes(textStyle: .body, color: titleTextColor(for: state))
			let prefix = cellData.title != "" ? "\n" : ""
			let summaryAttributed = NSAttributedString(string: prefix + cellData.summary, attributes: summaryAttributes)
			attributedCellText.append(summaryAttributed)
		}

		articleContent.attributedText = attributedCellText

		let linesUsed = countLines(of: attributedCellText, width: articleContent.bounds.width)
		let lineBreakMode: NSLineBreakMode = linesUsed >= cellData.numberOfLines ? .byTruncatingTail : .byWordWrapping
		articleContent.lineBreakMode = lineBreakMode
	}

	func titleTextColor(for state: UICellConfigurationState) -> UIColor {
		isActive(state) ? .white : .label
	}

	func countLines(of attributedString: NSAttributedString, width: CGFloat) -> Int {
		let textStorage = NSTextStorage(attributedString: attributedString)
		let textContainer = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
		let layoutManager = NSLayoutManager()

		layoutManager.addTextContainer(textContainer)
		textStorage.addLayoutManager(layoutManager)

		textContainer.lineFragmentPadding = 0 // UILabel uses 0 or very small
		layoutManager.ensureLayout(for: textContainer)

		var lineCount = 0
		var index = 0
		var lineRange = NSRange()

		while index < layoutManager.numberOfGlyphs {
			layoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
			index = NSMaxRange(lineRange)
			lineCount += 1
		}
		return lineCount
	}
}
