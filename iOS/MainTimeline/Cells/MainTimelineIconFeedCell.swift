//
//  PseudoFeedTableViewCell.swift
//  NetNewsWire
//
//  Created by Stuart Breckenridge on 19/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineIconFeedCell: UITableViewCell {

	@IBOutlet weak var articleTitle: UILabel!
	@IBOutlet weak var authorByLine: UILabel!
	@IBOutlet weak var iconView: IconView!
	@IBOutlet weak var indicatorView: IconView!
	@IBOutlet weak var articleDate: UILabel!
	@IBOutlet weak var metaDataStackView: UIStackView!

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
			iconView.translatesAutoresizingMaskIntoConstraints = false
			configureStackView()
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


	private func configure(_ cellData: MainTimelineCellData) {
		updateIndicatorView(cellData)
		articleTitle.numberOfLines = cellData.numberOfLines
		applyTitleTextWithAttributes(configurationState)

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

	private func setIconImage(_ iconImage: IconImage?, with size: IconSize) {
		iconView.iconImage = iconImage
		updateIconViewSizeConstraints(to: size.size)
	}

	func setIconImage(_ iconImage: IconImage?) {
		iconView.iconImage = iconImage
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



		let isSelected = state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped
		if cellData.title != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .headline).pointSize
			paragraphStyle.lineBreakMode = .byTruncatingTail
			let titleAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .headline),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: isSelected ? UIColor.white : UIColor.label
			]
			let titleWithNewline = cellData.title + (cellData.summary != "" ? "\n" : "" ) 
			let titleAttributed = NSAttributedString(string: titleWithNewline, attributes: titleAttributes)
			attributedCellText.append(titleAttributed)
		}
		if cellData.summary != "" {
			let paragraphStyle = NSMutableParagraphStyle()
			paragraphStyle.minimumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
			paragraphStyle.maximumLineHeight = UIFont.preferredFont(forTextStyle: .body).pointSize
			paragraphStyle.lineBreakMode = .byTruncatingTail
			let summaryAttributes: [NSAttributedString.Key: Any] = [
				.font: UIFont.preferredFont(forTextStyle: .body),
				.paragraphStyle: paragraphStyle,
				.foregroundColor: isSelected ? UIColor.white : UIColor.label
			]
			let summaryAttributed = NSAttributedString(string: cellData.summary, attributes: summaryAttributes)
			attributedCellText.append(summaryAttributed)
		}
		articleTitle.attributedText = attributedCellText
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		super.updateConfiguration(using: state)

		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		backgroundConfig.cornerRadius = 20
		if traitCollection.userInterfaceIdiom == .pad {
			backgroundConfig.edgesAddingLayoutMarginsToBackgroundInsets = [.leading, .trailing]
			backgroundConfig.backgroundInsets = NSDirectionalEdgeInsets(top: 0, leading: !isPreview ? -4 : -12, bottom: 0, trailing: !isPreview ? -4 : -12)
		}

		if state.isSelected || state.isHighlighted || state.isFocused || state.isSwiped {
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			applyTitleTextWithAttributes(state)
			articleDate.textColor = .lightText
			authorByLine.textColor = .lightText
		} else {
			applyTitleTextWithAttributes(state)
			articleDate.textColor = .secondaryLabel
			authorByLine.textColor = .secondaryLabel
		}

		self.backgroundConfiguration = backgroundConfig

	}

}
