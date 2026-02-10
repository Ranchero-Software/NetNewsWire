//
//  MainTimelineCollectionViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 24/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineCollectionViewCell: UICollectionViewCell {
	@IBOutlet var articleContent: UILabel!
	@IBOutlet var articleByLine: UILabel!
	@IBOutlet var feedIcon: IconView?
	@IBOutlet var indicatorView: IconView!
	@IBOutlet var articleDate: UILabel!
	@IBOutlet var metaDataStackView: UIStackView!
	@IBOutlet var topSeparator: UIView!

	var cellData: MainTimelineCellData! {
		didSet {
			configure(cellData)
		}
	}

	var isPreview: Bool = false

	// Cached Values
	private var rangeOfTitle: NSRange?
	private var rangeOfSummary: NSRange?
	private var title: String = ""
	private var summary: String = ""

	private static let indicatorAnimationDuration = 0.25

	// Paragraph Styles
	private static let baseWrappingParagraphStyle: NSParagraphStyle = {
		let style = NSMutableParagraphStyle()
		style.lineBreakMode = .byWordWrapping
		style.lineBreakStrategy = []
		style.hyphenationFactor = 1.0
		style.allowsDefaultTighteningForTruncation = true
		return style
	}()
	private static let headlineBaseParagraphStyle: NSParagraphStyle = {
		let style = (baseWrappingParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
		return style
	}()
	private static let summaryBaseParagraphStyle: NSParagraphStyle = {
		let style = (baseWrappingParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
		return style
	}()

	// Text Storage
	private lazy var lineCountTextStorage = NSTextStorage()
	private lazy var lineCountLayoutManager: NSLayoutManager = {
		let lm = NSLayoutManager()
		lineCountTextStorage.addLayoutManager(lm)
		return lm
	}()
	private lazy var lineCountTextContainer: NSTextContainer = {
		let tc = NSTextContainer(size: .zero)
		tc.lineFragmentPadding = 0
		lineCountLayoutManager.addTextContainer(tc)
		return tc
	}()

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			indicatorView.alpha = 0.0
			feedIcon?.translatesAutoresizingMaskIntoConstraints = false
			configureStackView()

			registerForTraitChanges([UITraitPreferredContentSizeCategory.self], target: self, action: #selector(configureStackView))
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()
		rangeOfTitle = nil
		rangeOfSummary = nil
		title = ""
		summary = ""
	}

	private func configure(_ cellData: MainTimelineCellData) {
		articleContent.numberOfLines = cellData.numberOfLines
		updateIndicatorView(configurationState)
		if title != cellData.title || summary != cellData.summary {
			title = cellData.title
			summary = cellData.summary
			addArticleContent(configurationState)
		}

		if cellData.showFeedName == .feed {
			articleByLine.text = cellData.feedName
		} else if cellData.showFeedName == .byline {
			articleByLine.text = cellData.byline
		} else if cellData.showFeedName == .none {
			articleByLine.text = ""
		}

		if feedIcon != nil {
			setIconImage(cellData.iconImage, with: cellData.iconSize)
		}

		articleDate.text = cellData.dateString
		updateAccessibilityLabel()
	}
	
	func updateAccessibilityLabel() {
		let starredStatus = cellData.starred ? "\(NSLocalizedString("Starred", comment: "Starred article for accessibility")), " : ""
		let unreadStatus = cellData.read ? "" : "\(NSLocalizedString("Unread", comment: "Unread")), "
		let label = starredStatus + unreadStatus + "\(cellData.feedName), \(cellData.title), \(cellData.summary), \(cellData.dateString)"
		accessibilityLabel = label
	}

	private func updateIndicatorView(_ state: UICellConfigurationState) {
		if cellData.read == false {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
				self.indicatorView.tintColor = (state.isSelected && !state.isSwiped) ? .white : Assets.Colors.secondaryAccent
			}
			return
		} else if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = (state.isSelected && !state.isSwiped) ? .white : Assets.Colors.star
			}
			return
		} else if indicatorView.alpha == 1.0 {
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.alpha = 0.0
				self.indicatorView.iconImage = nil
			}
		}
	}

	@objc private func configureStackView() {
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

	private func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
		if feedIcon != nil {
			updateIconViewSizeConstraints(to: size.size)
			feedIcon!.iconImage = iconImage
		}
	}

	private func updateIconViewSizeConstraints(to size: CGSize) {
		guard feedIcon != nil else { return }

		for constraint in feedIcon!.constraints.compactMap({ $0 }) {
			constraint.isActive = false
		}

		NSLayoutConstraint.activate([
			feedIcon!.widthAnchor.constraint(equalToConstant: size.width),
			feedIcon!.heightAnchor.constraint(equalToConstant: size.height)
		])

		setNeedsLayout()
	}

	private func addArticleContent(_ state: UICellConfigurationState) {
		let attributedCellText = NSMutableAttributedString()

		// 1. Prepare Title
		if cellData.title != "" {
			let titleFont = UIFont.preferredFont(forTextStyle: .headline)
			let lineHeight = titleFont.lineHeight

			let paragraphStyle = (Self.headlineBaseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
			paragraphStyle.minimumLineHeight = lineHeight
			paragraphStyle.maximumLineHeight = lineHeight

			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: titleFont,
				.paragraphStyle: paragraphStyle,
				.foregroundColor: UIColor.label
			]

			let titleAttributed = NSAttributedString(string: cellData.title, attributes: titleAttributes)
			let titleLength = titleAttributed.length
			let tentativeTitleRange = NSRange(location: 0, length: titleLength)
			rangeOfTitle = tentativeTitleRange

			let linesUsed = countLines(titleAttributed, width: articleContent.bounds.width)
			// 2. Measure Title Height
			if linesUsed >= cellData.numberOfLines {
				// The title already fills the available lines, set it and exit
				articleContent.attributedText = titleAttributed
				articleContent.lineBreakMode = .byTruncatingTail
				// Title occupies the whole label content in this path
				rangeOfTitle = NSRange(location: 0, length: titleAttributed.length)
				return
			}

			attributedCellText.append(titleAttributed)
			rangeOfTitle = NSRange(location: 0, length: titleAttributed.length)
		}

		// 3. Prepare Summary (Only reached if Title < 3 lines)
		if cellData.summary != "" {
			let summaryFont = UIFont.preferredFont(forTextStyle: .body)
			let summaryLineHeight = summaryFont.lineHeight

			let paragraphStyle = (Self.summaryBaseParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
			paragraphStyle.minimumLineHeight = summaryLineHeight
			paragraphStyle.maximumLineHeight = summaryLineHeight

			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: summaryFont,
				.paragraphStyle: paragraphStyle,
				.foregroundColor: cellData.title != "" ? UIColor.secondaryLabel : UIColor.label
			]

			let prefix = cellData.title != "" ? "\n" : ""
			let summaryAttributed = NSAttributedString(string: prefix + cellData.summary, attributes: summaryAttributes)
			let currentLength = attributedCellText.length
			let start = currentLength
			let length = summaryAttributed.length
			rangeOfSummary = NSRange(location: start, length: length)

			attributedCellText.append(summaryAttributed)
		}

		let linesUsed = countLines(attributedCellText, width: articleContent.bounds.width)
		if linesUsed >= cellData.numberOfLines {
			// The title already fills 3 lines, set it and exit
			articleContent.attributedText = attributedCellText
			articleContent.lineBreakMode = .byTruncatingTail
			return
		} else {
			articleContent.attributedText = attributedCellText
			articleContent.lineBreakMode = .byWordWrapping
		}

	}

	func adjustArticleContentColor() {
		func applyTitleColour() {
			guard let titleRange = rangeOfTitle, titleRange.location != NSNotFound, titleRange.length > 0 else { return }
			guard let current = articleContent.attributedText else { return }
			let mutable = NSMutableAttributedString(attributedString: current)
			mutable.addAttribute(.foregroundColor, value: UIColor.label, range: titleRange)
			articleContent.attributedText = mutable
		}
		func applySummaryColour() {
			guard let summaryRange = rangeOfSummary, summaryRange.location != NSNotFound, summaryRange.length > 0 else { return }
			guard let current = articleContent.attributedText else { return }
			let mutable = NSMutableAttributedString(attributedString: current)
			mutable.addAttribute(.foregroundColor, value: cellData.title == "" ? UIColor.label : UIColor.secondaryLabel, range: summaryRange)
			articleContent.attributedText = mutable
		}

		if configurationState.isSwiped && configurationState.isSelected {
			articleContent.textColor = .white
			articleByLine.textColor = .white
			articleDate.textColor = .white
		} else if configurationState.isSwiped && !configurationState.isSelected {
			applyTitleColour()
			applySummaryColour()
			articleByLine.textColor = .secondaryLabel
			articleDate.textColor = .secondaryLabel
		} else if !configurationState.isSwiped && configurationState.isSelected {
			articleContent.textColor = .white
			articleByLine.textColor = .white
			articleDate.textColor = .white
		} else {
			applyTitleColour()
			applySummaryColour()
			articleByLine.textColor = .secondaryLabel
			articleDate.textColor = .secondaryLabel
		}
	}

	func countLines(_ attributed: NSAttributedString, width: CGFloat) -> Int {
		lineCountTextContainer.size = CGSize(width: width, height: .greatestFiniteMagnitude)
		lineCountTextStorage.setAttributedString(attributed)
		lineCountLayoutManager.ensureLayout(for: lineCountTextContainer)

		var lineCount = 0
		var index = 0
		var lineRange = NSRange()
		while index < lineCountLayoutManager.numberOfGlyphs {
			lineCountLayoutManager.lineFragmentRect(forGlyphAt: index, effectiveRange: &lineRange)
			index = NSMaxRange(lineRange)
			lineCount += 1
		}
		return lineCount
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)

		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		backgroundConfig.cornerRadius = 20

		backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
		if UIDevice.current.userInterfaceIdiom == .pad {
			backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -8, bottom: 0, trailing: -8)
		} else {
			if !isPreview {
				backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -12, bottom: 0, trailing: -12)
			} else {
				backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16)
			}
		}

		if state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			topSeparator.alpha = 0.0
		} else if state.isSwiped && !state.isSelected {
			backgroundConfig.backgroundColor = .secondarySystemFill
			topSeparator.alpha = 0.0
		} else if !state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			topSeparator.alpha = 0.0
		} else {
			backgroundConfig.backgroundColor = .clear
			topSeparator.alpha = 1.0
		}
		adjustArticleContentColor()
		updateIndicatorView(state)

		if isPreview {
			backgroundConfig.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
			topSeparator.alpha = 0.0
		}

		self.backgroundConfiguration = backgroundConfig
	}

}
