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

class CapsuleBackgroundView: UIView {
	
	override func layoutSubviews() {
		super.layoutSubviews()
		if UIDevice.current.userInterfaceIdiom == .pad {
			self.layer.cornerRadius = self.bounds.height / 2
		} else {
			self.layer.cornerRadius = 8
		}
		
		self.layer.masksToBounds = true
	}
}


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
	
	override var isSelected: Bool {
		didSet {
			if UIDevice.current.userInterfaceIdiom == .pad {
				feedTitle.textColor = isSelected ? AppAssets.primaryAccentColor : .label
			}
			selectedBackgroundView?.backgroundColor = isSelected ? .tertiarySystemFill : .clear
			if UIDevice.current.userInterfaceIdiom == .phone {
				backgroundColor = isSelected ? .clear : .systemBackground
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
		selectedBackgroundView = CapsuleBackgroundView()
		selectedBackgroundView?.layoutSubviews()
		if UIDevice.current.userInterfaceIdiom == .pad {
			backgroundColor = .clear
		}
		
    }
		
}

