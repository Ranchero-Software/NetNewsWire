//
//  MainFeedCollectionHeaderReusableView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit

protocol MainFeedCollectionHeaderReusableViewDelegate: AnyObject {
	func mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(_ view: MainFeedCollectionHeaderReusableView)
}

class MainFeedCollectionHeaderReusableView: UICollectionReusableView {
	
	var delegate: MainFeedCollectionHeaderReusableViewDelegate?
	
	@IBOutlet weak var headerTitle: UILabel!
	@IBOutlet weak var disclosureIndicator: UIImageView!
	@IBOutlet weak var unreadCountLabel: UILabel!
	private var unreadLabelWidthConstraint: NSLayoutConstraint?
	
	
	override var accessibilityLabel: String? {
		set {}
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(headerTitle.text ?? "") \(unreadCount) \(unreadLabel) \(expandedStateMessage) "
			} else {
				return "\(headerTitle.text ?? "") \(expandedStateMessage) "
			}
		}
	}

	private var expandedStateMessage: String {
		set {}
		get {
			if disclosureExpanded {
				return NSLocalizedString("Expanded", comment: "Disclosure button expanded state for accessibility")
			}
			return NSLocalizedString("Collapsed", comment: "Disclosure button collapsed state for accessibility")
		}
	}
	
	
	private var _unreadCount: Int = 0
	
	var unreadCount: Int {
		get {
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			updateUnreadCount()
			unreadCountLabel.text = newValue.formatted()
		}
	}
	
	var disclosureExpanded = true {
		didSet {
			updateExpandedState(animate: true)
			updateUnreadCount()
		}
	}
	
	override func awakeFromNib() {
		super.awakeFromNib()
		unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
		unreadLabelWidthConstraint?.isActive = true
		configureUI()
		addTapGesture()
	}
	
	func configureUI() {
		headerTitle.textColor = traitCollection.userInterfaceIdiom == .pad ? .tertiaryLabel : .label
	}
	
	private func addTapGesture() {
		let tapGesture = UITapGestureRecognizer(target: self, action: #selector(containerHeaderTapped))
		self.addGestureRecognizer(tapGesture)
		self.isUserInteractionEnabled = true
	}
	
	@objc private func containerHeaderTapped() {
		delegate?.mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(self)
	}
		
	func configureContainer(withTitle title: String) {
		headerTitle.text = title
		disclosureIndicator.transform = .identity
	}
	
	func updateExpandedState(animate: Bool) {
	
		if disclosureExpanded == false {
			unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80)
		} else {
			unreadLabelWidthConstraint = unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 0)
			unreadLabelWidthConstraint?.isActive = false
		}
		
		let angle: CGFloat = disclosureExpanded ? 0 : -.pi / 2
		let transform = CGAffineTransform(rotationAngle: angle)
		let animations = {
			self.disclosureIndicator.transform = transform
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
	
}
