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
	
	override func layoutSubviews() {
		super.layoutSubviews()
	}
	
	private func configure(_ cellData: MainTimelineCellData) {
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
			setIconImage(cellData.iconImage, with: cellData.iconSize)
		}
		
		articleDate.text = cellData.dateString
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
		}
		else if cellData.starred {
			if indicatorView.alpha == 0.0 {
				indicatorView.alpha = 1.0
			}
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
				self.indicatorView.iconImage = Assets.Images.starredFeed
				self.indicatorView.tintColor = (state.isSelected && !state.isSwiped) ? .white : Assets.Colors.star
			}
			return
		}
		else if indicatorView.alpha == 1.0 {
			UIView.animate(withDuration: Self.indicatorAnimationDuration) {
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
				.foregroundColor: UIColor.label
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
			paragraphStyle.lineBreakMode = .byWordWrapping
			paragraphStyle.lineBreakStrategy = []
			paragraphStyle.hyphenationFactor = 1.0
			paragraphStyle.allowsDefaultTighteningForTruncation = true
			
			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: summaryFont,
				.paragraphStyle: paragraphStyle,
				.foregroundColor: cellData.title != "" ? UIColor.secondaryLabel : UIColor.label
			]
			
			let prefix = cellData.title != "" ? "\n" : ""
			let summaryAttributed = NSAttributedString(string: prefix + cellData.summary, attributes: summaryAttributes)
			attributedCellText.append(summaryAttributed)
		}
		
		let linesUsed = countLines(of: attributedCellText, width: articleContent.bounds.width)
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
		if configurationState.isSwiped && configurationState.isSelected {
			articleContent.textColor = .white
			articleByLine.textColor = .white
			articleDate.textColor = .white
		} else if configurationState.isSwiped && !configurationState.isSelected {
			addArticleContent(configurationState)
			articleByLine.textColor = .secondaryLabel
			articleDate.textColor = .secondaryLabel
		} else if !configurationState.isSwiped && configurationState.isSelected {
			articleContent.textColor = .white
			articleByLine.textColor = .white
			articleDate.textColor = .white
		} else {
			addArticleContent(configurationState)
			articleByLine.textColor = .secondaryLabel
			articleDate.textColor = .secondaryLabel
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
			backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: !isPreview ? -12 : -12, bottom: 0, trailing: !isPreview ? -12 : -12)
		}
		
		if state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
		} else if state.isSwiped && !state.isSelected {
			backgroundConfig.backgroundColor = .secondarySystemFill
		} else if !state.isSwiped && state.isSelected {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
		} else {
			backgroundConfig.backgroundColor = .clear
		}
		adjustArticleContentColor()
		updateIndicatorView(state)
		
		self.backgroundConfiguration = backgroundConfig
	}
}

