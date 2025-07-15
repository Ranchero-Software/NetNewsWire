//
//  MainFeedCollectionViewFolderCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

protocol MainFeedCollectionViewFolderCellDelegate: AnyObject {
	func mainFeedCollectionFolderViewCellDisclosureDidToggle(_ sender: MainFeedCollectionViewFolderCell, expanding: Bool)
}

class MainFeedCollectionViewFolderCell: UICollectionViewCell {
    
	@IBOutlet weak var folderTitle: UILabel!
	@IBOutlet weak var faviconView: IconView!
	@IBOutlet weak var unreadCountLabel: UILabel!
	@IBOutlet weak var disclosureButton: UIButton!
	
	var delegate: MainFeedCollectionViewFolderCellDelegate?
	
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
	
	var disclosureExpanded = true {
		didSet {
			updateExpandedState(animate: true)
			updateUnreadCount()
		}
	}
	
	override var isSelected: Bool {
		didSet {
			if UIDevice.current.userInterfaceIdiom == .pad {
				folderTitle.textColor = isSelected ? AppAssets.primaryAccentColor : .label
				selectedBackgroundView?.backgroundColor = isSelected ? .tertiarySystemFill : .clear
			}
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		if UIDevice.current.userInterfaceIdiom == .pad {
			selectedBackgroundView = CapsuleBackgroundView()
			selectedBackgroundView?.layoutSubviews()
			backgroundColor = .clear
		}
		disclosureButton.addInteraction(UIPointerInteraction())
	}
	
	func updateExpandedState(animate: Bool) {
		let angle: CGFloat = disclosureExpanded ? 0 : -.pi / 2
		let transform = CGAffineTransform(rotationAngle: angle)
		let animations = {
			self.disclosureButton.transform = transform
		}
		if animate {
			UIView.animate(withDuration: 0.3, animations: animations)
		} else {
			animations()
		}
	}
	
	func updateUnreadCount() {
		if !disclosureExpanded && unreadCount > 0 {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountLabel.alpha = 1
			}
		} else {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountLabel.alpha = 0
			}
		}
	}
	
	@IBAction
	func toggleDisclosure() {
		setDisclosure(isExpanded: !disclosureExpanded, animated: true)
		delegate?.mainFeedCollectionFolderViewCellDisclosureDidToggle(self, expanding: disclosureExpanded)
	}
	
	func setDisclosure(isExpanded: Bool, animated: Bool) {
		disclosureExpanded = isExpanded
		print("disclosure is \(disclosureExpanded)")
	}
	
	
}
