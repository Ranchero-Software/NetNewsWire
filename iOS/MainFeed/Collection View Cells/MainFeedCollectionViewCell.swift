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


class MainFeedCollectionViewCell: UICollectionViewCell {
    
	@IBOutlet weak var feedTitle: UILabel!
	@IBOutlet weak var faviconView: IconView!
	@IBOutlet weak var unreadCountLabel: UILabel!
	private var faviconLeadingConstraint: NSLayoutConstraint?
	
	var iconImage: IconImage? {
		didSet {
			faviconView.iconImage = iconImage
			if let preferredColor = iconImage?.preferredColor {
				faviconView.tintColor = UIColor(cgColor: preferredColor)
			} else {
				faviconView.tintColor = AppAssets.secondaryAccentColor
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
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(String(describing: feedTitle.text)) \(unreadCount) \(unreadLabel)"
			} else {
				return (String(describing: feedTitle.text))
			}
		}
	}
	
    override func awakeFromNib() {
        super.awakeFromNib()
		faviconLeadingConstraint = faviconView.leadingAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.leadingAnchor)
		faviconLeadingConstraint?.isActive = true
    }
	
	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		
		switch (state.isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
		case (true, .pad):
			backgroundConfig.backgroundColor = .tertiarySystemFill
			feedTitle.textColor = AppAssets.primaryAccentColor
			feedTitle.font = feedTitle.font.bold()
		case (true, .phone):
			backgroundConfig.backgroundColor = AppAssets.primaryAccentColor
			feedTitle.textColor = .white
			unreadCountLabel.textColor = .lightText
			if feedTitle.text == "All Unread" {
				faviconView.tintColor = .white
			}
		default:
			feedTitle.textColor = .label
			feedTitle.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.textColor = .secondaryLabel
			if traitCollection.userInterfaceIdiom == .phone {
				if feedTitle.text == "All Unread" {
					if let preferredColor = iconImage?.preferredColor {
						faviconView.tintColor = UIColor(cgColor: preferredColor)
					} else {
						faviconView.tintColor = AppAssets.secondaryAccentColor
					}
				}
			}
		}
		self.backgroundConfiguration = backgroundConfig
	}
		
}

