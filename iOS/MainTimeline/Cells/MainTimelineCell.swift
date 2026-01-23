//
//  MainTimelineCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 22/01/2026.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineCell: UITableViewCell {
	
	@IBOutlet var articleContent: UILabel!
	@IBOutlet var articleByLine: UILabel!
	@IBOutlet var feedIcon: IconView?
	@IBOutlet var indicatorView: IconView!
	@IBOutlet var articleDate: UILabel!
	@IBOutlet var metaDataStackView: UIStackView!
	
	private(set) var usedTitleLineCount: Int = 0
	
	
	var cellData: MainTimelineCellData! {
		didSet {
			configure(cellData)
		}
	}
	
	var isPreview: Bool = false
	
	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			indicatorView.alpha = 0.0
			configureStackView()
		}
	}
	
	override func layoutSubviews() {
		super.layoutSubviews()
	}
	
	private func configure(_ cellData: MainTimelineCellData) {
		updateIndicatorView(cellData)
		articleContent.numberOfLines = cellData.numberOfLines
		addArticleContent(configurationState)
		
		if cellData.showFeedName == .feed {
			articleByLine.text = cellData.feedName
		} else if cellData.showFeedName == .byline {
			articleByLine.text = cellData.byline
		} else if cellData.showFeedName == .none {
			articleByLine.text = ""
		}
		
		if feedIcon != nil {
			setIconImage(cellData.iconImage)
		}
		
		articleDate.text = cellData.dateString
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
	
	func setIconImage(_ iconImage: IconImage?) {
		if feedIcon!.iconImage !== iconImage {
			feedIcon!.iconImage = iconImage
		}
	}
	
	
	private func addArticleContent(_ state: UICellConfigurationState) {
		let attributedCellText = NSMutableAttributedString()
		
		// 1. Prepare Title
		if cellData.title != "" {
			let titleFont = UIFont.preferredFont(forTextStyle: .headline)
			let lineHeight = titleFont.lineHeight
			
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = lineHeight
			paragraphStyle.maximumLineHeight = lineHeight
			paragraphStyle.lineBreakMode = .byWordWrapping
			paragraphStyle.lineBreakStrategy = []
			paragraphStyle.hyphenationFactor = 1.0
			paragraphStyle.allowsDefaultTighteningForTruncation = true
			
			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: titleFont,
				.paragraphStyle: paragraphStyle,
				.foregroundColor: titleTextColor(for: state)
			]
			
			let titleAttributed = NSAttributedString(string: cellData.title, attributes: titleAttributes)
			let linesUsed = countLines(of: titleAttributed, width: articleContent.bounds.width)
			// 2. Measure Title Height
			if linesUsed >= cellData.numberOfLines {
				// The title already fills 3 lines, set it and exit
				articleContent.attributedText = titleAttributed
				articleContent.lineBreakMode = .byTruncatingTail
				return
			}
		
			attributedCellText.append(titleAttributed)
		}
		
		// 3. Prepare Summary (Only reached if Title < 3 lines)
		if cellData.summary != "" {
			let summaryFont = UIFont.preferredFont(forTextStyle: .body)
			let summaryLineHeight = summaryFont.lineHeight
			
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = summaryLineHeight
			paragraphStyle.maximumLineHeight = summaryLineHeight
			paragraphStyle.lineBreakMode = .byTruncatingTail
			paragraphStyle.lineBreakStrategy = []
			paragraphStyle.hyphenationFactor = 1.0
			paragraphStyle.allowsDefaultTighteningForTruncation = true
			
			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: summaryFont,
				.paragraphStyle: paragraphStyle,
				.foregroundColor: titleTextColor(for: state)
			]
			
			let prefix = cellData.title != "" ? "\n" : ""
			let summaryAttributed = NSAttributedString(string: prefix + cellData.summary, attributes: summaryAttributes)
			attributedCellText.append(summaryAttributed)
		}
		
		articleContent.attributedText = attributedCellText
	}
	
	func titleTextColor(for state: UICellConfigurationState) -> UIColor {
		let isSelected = state.isSelected || state.isHighlighted || state.isEditing || state.isSwiped
		if isSelected {
			return .white
		} else {
			return .label
		}
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
			articleContent.textColor = titleTextColor(for: state)
			articleDate.textColor = .lightText
			articleByLine.textColor = .lightText
		} else {
			articleContent.textColor = titleTextColor(for: state)
			articleDate.textColor = .secondaryLabel
			articleByLine.textColor = .secondaryLabel
		}
		
		self.backgroundConfiguration = backgroundConfig
	}
	
}

