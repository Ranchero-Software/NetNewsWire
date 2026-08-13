//
//  MainFeedCollectionHeaderReusableView.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 12/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import Account

@MainActor protocol MainFeedCollectionHeaderReusableViewDelegate: AnyObject {
	func mainFeedCollectionHeaderReusableViewDidTapDisclosureIndicator(_ view: MainFeedCollectionHeaderReusableView)
}

enum SectionHeaderType {
	case smartFeeds
	case account(String) // accountID
}

final class MainFeedCollectionHeaderReusableView: UICollectionReusableView {
	var delegate: MainFeedCollectionHeaderReusableViewDelegate?
	var sectionHeaderType: SectionHeaderType?

	@IBOutlet var headerTitle: UILabel!
	@IBOutlet var disclosureIndicator: UIImageView!
	@IBOutlet var unreadCountLabel: UILabel!

	override var accessibilityLabel: String? {
		get {
			if unreadCount > 0 {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessibility")
				return "\(headerTitle.text ?? "") \(unreadCount) \(unreadLabel) \(expandedStateMessage) "
			} else {
				return "\(headerTitle.text ?? "") \(expandedStateMessage) "
			}
		}
		set {}
	}

	private var expandedStateMessage: String {
		if disclosureExpanded {
			return NSLocalizedString("Expanded", comment: "Expanded")
		}
		return NSLocalizedString("Collapsed", comment: "Collapsed")
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

	// Mutate via setDisclosure(isExpanded:animated:) — the supplementary provider
	// sets this on every dequeue and must not animate.
	private(set) var disclosureExpanded = true

	func setDisclosure(isExpanded: Bool, animated: Bool) {
		disclosureExpanded = isExpanded
		updateExpandedState(animate: animated)
		updateUnreadCount(animated: animated)
	}

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			isAccessibilityElement = true
			headerTitle.isAccessibilityElement = false
			unreadCountLabel.isAccessibilityElement = false
			disclosureIndicator.isAccessibilityElement = false
			unreadCountLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 80).isActive = true
			configureUI()
			addTapGesture()
		}
	}

	override func prepareForReuse() {
		super.prepareForReuse()

		sectionHeaderType = nil

		let contextMenuInteractions = interactions.compactMap { $0 as? UIContextMenuInteraction }
		for interaction in contextMenuInteractions {
			removeInteraction(interaction)
		}
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

	func updateUnreadCount(animated: Bool = true) {
		let alpha: CGFloat = (!disclosureExpanded && unreadCount > 0) ? 1 : 0
		if animated {
			UIView.animate(withDuration: 0.3) {
				self.unreadCountLabel.alpha = alpha
			}
		} else {
			unreadCountLabel.alpha = alpha
		}
	}

}
