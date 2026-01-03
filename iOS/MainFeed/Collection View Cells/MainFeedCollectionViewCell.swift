//
//  MainFeedCollectionViewCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 23/06/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Account
import RSTree

final class MainFeedCollectionViewCell: UICollectionViewCell {
	@IBOutlet var feedTitle: UILabel!
	@IBOutlet var faviconView: IconView!
	@IBOutlet var unreadCountLabel: UILabel!
	private var faviconLeadingConstraint: NSLayoutConstraint?

	var iconImage: IconImage? {
		didSet {
			faviconView.iconImage = iconImage
			if let preferredColor = iconImage?.preferredColor {
				faviconView.tintColor = UIColor(cgColor: preferredColor)
			} else {
				faviconView.tintColor = Assets.Colors.secondaryAccent
			}
		}
	}

	private var _unreadCount: Int = 0

	var unreadCount: Int {
		get {
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			if newValue == 0 {
				unreadCountLabel.isHidden = true
			} else {
				unreadCountLabel.isHidden = false
			}
			unreadCountLabel.text = newValue.formatted()
		}
	}

	/// If the feed is contained in a folder, the indentation level is 1
	/// and the cell's favicon leading constrain is increased. Otherwise,
	/// it has the standard leading constraint.
	///
	/// On the storyboard, no leading constraint is set.
	var indentationLevel: Int = 0 {
		didSet {
			if indentationLevel == 1 {
				faviconLeadingConstraint?.constant = 32
			} else {
				faviconLeadingConstraint?.constant = 16
			}
		}
	}

	override var accessibilityLabel: String? {
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(String(describing: feedTitle.text)) \(unreadCount) \(unreadLabel)"
			} else {
				return (String(describing: feedTitle.text))
			}
		}
		set {}
	}

    override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			faviconLeadingConstraint = faviconView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor)
			faviconLeadingConstraint?.isActive = true
		}
    }

	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)

		switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
		case (true, .pad):
			backgroundConfig.backgroundColor = .tertiarySystemFill
			feedTitle.textColor = Assets.Colors.primaryAccent
			feedTitle.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
											   weight: .semibold)
			unreadCountLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
		case (true, .phone):
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			feedTitle.textColor = .white
			unreadCountLabel.textColor = .secondaryLabel
			if feedTitle.text == "All Unread" {
				faviconView.tintColor = .white
			}
		default:
			feedTitle.textColor = .label
			feedTitle.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.textColor = .secondaryLabel
			if traitCollection.userInterfaceIdiom == .phone {
				if feedTitle.text == "All Unread" {
					if let preferredColor = iconImage?.preferredColor {
						faviconView.tintColor = UIColor(cgColor: preferredColor)
					} else {
						faviconView.tintColor = Assets.Colors.secondaryAccent
					}
				}
			}
		}
		self.backgroundConfiguration = backgroundConfig
	}
}
