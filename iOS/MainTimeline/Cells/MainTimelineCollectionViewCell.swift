//
//  MainTimelineCollectionViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 24/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Articles
import Images

@MainActor private final class ArticleContentCache: NSObject {

	struct Key: Hashable {
		let accountID: String
		let articleID: String
	}

	struct Entry {
		let width: CGFloat
		let numberOfLines: Int
		let contentSizeCategory: UIContentSizeCategory
		let attributedText: NSAttributedString
		let rangeOfTitle: NSRange?
		let rangeOfSummary: NSRange?
	}

	private var storage = [Key: Entry]()

	override init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(articlesDidDownload(_:)), name: .AccountDidDownloadArticles, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleLowMemory(_:)), name: .lowMemory, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleAppDidGoToBackground(_:)), name: .appDidGoToBackground, object: nil)
	}

	func entry(for key: Key) -> Entry? {
		storage[key]
	}

	func setEntry(_ entry: Entry, for key: Key) {
		storage[key] = entry
	}

	@objc private func articlesDidDownload(_ note: Notification) {
		guard let updatedArticles = note.userInfo?[Account.UserInfoKey.updatedArticles] as? Set<Article> else {
			return
		}
		for article in updatedArticles {
			storage.removeValue(forKey: Key(accountID: article.accountID, articleID: article.articleID))
		}
	}

	@objc private func handleLowMemory(_ note: Notification) {
		storage.removeAll()
	}

	@objc private func handleAppDidGoToBackground(_ note: Notification) {
		storage.removeAll()
	}
}

final class MainTimelineCollectionViewCell: UICollectionViewCell {

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
	private var appliedIconSize: CGSize?

	private static let indicatorAnimationDuration = 0.25

	// Paragraph Styles
	private static let baseWrappingParagraphStyle: NSParagraphStyle = {
		let style = NSMutableParagraphStyle()
		style.lineBreakMode = .byTruncatingTail
		style.lineBreakStrategy = []
		style.hyphenationFactor = 1.0
		style.allowsDefaultTighteningForTruncation = true
		return style
	}()
	private static let headlineBaseParagraphStyle: NSParagraphStyle = {
		let style = (baseWrappingParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
		style.hyphenationFactor = 0.5
		return style
	}()
	private static let summaryBaseParagraphStyle: NSParagraphStyle = {
		let style = (baseWrappingParagraphStyle.mutableCopy() as! NSMutableParagraphStyle)
		return style
	}()

	private static let contentCache = ArticleContentCache()

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
			isAccessibilityElement = true
			articleContent.isAccessibilityElement = false
			articleByLine.isAccessibilityElement = false
			articleDate.isAccessibilityElement = false
			indicatorView.isAccessibilityElement = false
			feedIcon?.isAccessibilityElement = false
			indicatorView.alpha = 0.0
			topSeparator.backgroundColor = .separator.withAlphaComponent(0.1)
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

	private func updateAccessibilityLabel() {
		let starredStatus = cellData.starred ? "\(NSLocalizedString("Starred", comment: "Starred")), " : ""
		let unreadStatus = cellData.read ? "" : "\(NSLocalizedString("Unread", comment: "Unread")), "
		let label = starredStatus + unreadStatus + "\(cellData.feedName), \(cellData.title), \(cellData.summary), \(cellData.dateString)"
		accessibilityLabel = label
	}

	private func updateIndicatorView(_ state: UICellConfigurationState) {
		if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = (state.isSelected && !state.isSwiped) ? .white : Assets.Colors.star
			}
			return
		} else if cellData.read == false {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.unreadCellIndicator
				self.indicatorView.tintColor = (state.isSelected && !state.isSwiped) ? .white : Assets.Colors.secondaryAccent
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
		guard let feedIcon, appliedIconSize != size else {
			return
		}
		appliedIconSize = size

		for constraint in feedIcon.constraints {
			constraint.isActive = false
		}

		NSLayoutConstraint.activate([
			feedIcon.widthAnchor.constraint(equalToConstant: size.width),
			feedIcon.heightAnchor.constraint(equalToConstant: size.height)
		])

		setNeedsLayout()
	}

	private func addArticleContent(_ state: UICellConfigurationState) {
		let width = articleContent.bounds.width
		let numberOfLines = cellData.numberOfLines
		let contentSizeCategory = traitCollection.preferredContentSizeCategory

		let key = ArticleContentCache.Key(accountID: cellData.accountID, articleID: cellData.articleID)
		let entry: ArticleContentCache.Entry
		if let cached = Self.contentCache.entry(for: key),
		   cached.width == width, cached.numberOfLines == numberOfLines, cached.contentSizeCategory == contentSizeCategory {
			entry = cached
		} else {
			entry = buildArticleContent(width: width, numberOfLines: numberOfLines, contentSizeCategory: contentSizeCategory)
			if width > 0 {
				Self.contentCache.setEntry(entry, for: key)
			}
		}

		articleContent.attributedText = entry.attributedText
		rangeOfTitle = entry.rangeOfTitle
		rangeOfSummary = entry.rangeOfSummary
	}

	private func buildArticleContent(width: CGFloat, numberOfLines: Int, contentSizeCategory: UIContentSizeCategory) -> ArticleContentCache.Entry {
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

			// 2. If the title already fills the available lines, it occupies the whole label.
			let linesUsed = countLines(titleAttributed, width: width)
			if linesUsed >= numberOfLines {
				let titleRange = NSRange(location: 0, length: titleAttributed.length)
				return Self.entry(width, numberOfLines, contentSizeCategory, titleAttributed, titleRange, nil)
			}

			attributedCellText.append(titleAttributed)
		}

		let rangeOfTitle = cellData.title != "" ? NSRange(location: 0, length: attributedCellText.length) : nil

		// 3. Prepare Summary (only reached if the title is under numberOfLines).
		var rangeOfSummary: NSRange?
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
			rangeOfSummary = NSRange(location: attributedCellText.length, length: summaryAttributed.length)
			attributedCellText.append(summaryAttributed)
		}

		return Self.entry(width, numberOfLines, contentSizeCategory, attributedCellText, rangeOfTitle, rangeOfSummary)
	}

	private static func entry(_ width: CGFloat, _ numberOfLines: Int, _ contentSizeCategory: UIContentSizeCategory, _ attributedText: NSAttributedString, _ rangeOfTitle: NSRange?, _ rangeOfSummary: NSRange?) -> ArticleContentCache.Entry {
		ArticleContentCache.Entry(width: width, numberOfLines: numberOfLines, contentSizeCategory: contentSizeCategory, attributedText: attributedText, rangeOfTitle: rangeOfTitle, rangeOfSummary: rangeOfSummary)
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
			} else {
				if !isPreview {
					backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -12, bottom: 0, trailing: -12)
				} else {
					backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: -16, bottom: 0, trailing: -16)
				}
			}
		} else {
			backgroundConfig.cornerRadius = 0
		}

		let isActive = state.isSwiped || state.isSelected

		if state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
		} else if state.isSwiped && !state.isSelected {
			backgroundConfig.backgroundColor = .secondarySystemFill
		} else if !state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
		} else {
			backgroundConfig.backgroundColor = .clear
		}

		// Hide this cell's separator when active, or when the cell
		// directly above is active (so no separator appears below a
		// highlighted row).
		let hideForPreviousCell = cellAboveIsActive()
		topSeparator.alpha = (isActive || hideForPreviousCell) ? 0.0 : 1.0
		adjustArticleContentColor()
		updateIndicatorView(state)

		if isPreview {
			backgroundConfig.backgroundColor = traitCollection.userInterfaceStyle == .dark ? .secondarySystemBackground : .white
			topSeparator.alpha = 0.0
		}

		self.backgroundConfiguration = backgroundConfig
	}

	private func cellAboveIsActive() -> Bool {
		guard let collectionView = superview as? UICollectionView,
			  let myIndexPath = collectionView.indexPath(for: self) else {
			return false
		}

		let section = myIndexPath.section
		let item = myIndexPath.item
		guard item > 0 else {
			return false
		}

		let previousIndexPath = IndexPath(item: item - 1, section: section)
		guard let previousCell = collectionView.cellForItem(at: previousIndexPath) else {
			return false
		}

		let state = previousCell.configurationState
		return state.isSelected || state.isSwiped
	}
}
