//
//  MainFeedCollectionViewFolderCell.swift
//  NetNewsWire-iOS
//
//  Created by Stuart Breckenridge on 14/07/2025.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import UIKit
import RSCore
import Images

@MainActor protocol MainFeedCollectionViewFolderCellDelegate: AnyObject {
	func mainFeedCollectionFolderViewCellDisclosureDidToggle(_ sender: MainFeedCollectionViewFolderCell, expanding: Bool)
}

class MainFeedCollectionViewFolderCell: UICollectionViewCell {
	@IBOutlet var folderTitle: UILabel!
	@IBOutlet var faviconView: IconView!
	@IBOutlet var unreadCountLabel: UILabel!
	@IBOutlet var disclosureButton: UIButton!

	var delegate: MainFeedCollectionViewFolderCellDelegate?

	private var _unreadCount: Int = 0
	var unreadCount: Int {
		get {
			return _unreadCount
		}
		set {
			_unreadCount = newValue
			let unreadCountText = unreadCountText
			unreadCountLabel.isHidden = unreadCountText == nil
			if unreadCountText != nil {
				updateUnreadCountVisibility()
			}
			unreadCountLabel.setUnreadCount(newValue)
			setNeedsUpdateConfiguration()
		}
	}

	private var unreadCountText: String? {
		AppDefaults.shared.unreadCountDisplay.text(for: unreadCount)
	}

	var iconImage: IconImage? {
		didSet {
			faviconView.iconImage = iconImage
			faviconView.tintColor = iconImage?.preferredColor ?? Assets.Colors.secondaryAccent
		}
	}

	// Mutate via setDisclosure(isExpanded:animated:) so configure-time calls
	// can skip animation — a 0.3s chevron spin during a diffable apply is wrong.
	private(set) var disclosureExpanded = true

	override func awakeFromNib() {
		MainActor.assumeIsolated {
			super.awakeFromNib()
			isAccessibilityElement = true
			folderTitle.isAccessibilityElement = false
			unreadCountLabel.isAccessibilityElement = false
			faviconView.isAccessibilityElement = false
			disclosureButton.isAccessibilityElement = false
			disclosureButton.addInteraction(UIPointerInteraction())
		}
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

	func updateUnreadCountVisibility(animated: Bool = true) {
		let alpha: CGFloat = (!disclosureExpanded && unreadCountText != nil) ? 1 : 0
		if animated {
			UIView.animate {
				self.unreadCountLabel.alpha = alpha
			}
		} else {
			unreadCountLabel.alpha = alpha
		}
	}

	@IBAction
	func toggleDisclosure() {
		setDisclosure(isExpanded: !disclosureExpanded, animated: true)
		delegate?.mainFeedCollectionFolderViewCellDisclosureDidToggle(self, expanding: disclosureExpanded)
	}

	func setDisclosure(isExpanded: Bool, animated: Bool) {
		disclosureExpanded = isExpanded
		updateExpandedState(animate: animated)
		updateUnreadCountVisibility(animated: animated)
	}

	override var accessibilityLabel: String? {
		get {
			let name = folderTitle.text ?? ""
			guard let unreadText = AppDefaults.shared.unreadCountDisplay.accessibilityText(for: unreadCount) else {
				return "\(name) \(expandedStateMessage)"
			}
			return "\(name) \(unreadText) \(expandedStateMessage)"
		}
		set {}
	}

	private var expandedStateMessage: String {
		if disclosureExpanded {
			return NSLocalizedString("Expanded", comment: "Expanded")
		}
		return NSLocalizedString("Collapsed", comment: "Collapsed")
	}

	override var accessibilityCustomActions: [UIAccessibilityCustomAction]? {
		get {
			let name: String
			if disclosureExpanded {
				name = NSLocalizedString("Collapse", comment: "Collapse")
			} else {
				name = NSLocalizedString("Expand", comment: "Expand")
			}
			let toggleAction = UIAccessibilityCustomAction(name: name) { [weak self] _ in
				self?.toggleDisclosure()
				return true
			}
			return [toggleAction]
		}
		set {}
	}

	override func updateConfiguration(using state: UICellConfigurationState) {
		var backgroundConfig: UIBackgroundConfiguration
		if #available(iOS 18, *) {
			backgroundConfig = UIBackgroundConfiguration.listCell().updated(for: state)
		} else if traitCollection.userInterfaceIdiom == .pad {
			backgroundConfig = UIBackgroundConfiguration.listSidebarCell().updated(for: state)
		} else {
			backgroundConfig = UIBackgroundConfiguration.listGroupedCell().updated(for: state)
		}

		// Matches the timeline: accent background and white text when the feeds list is first responder,
		// and no highlight while a row is pressed, so the row goes straight to the selected style.
		let isExpanded = isInExpandedSplitView
		let isActiveSelection = state.isSelected && isExpanded && enclosingViewController?.isFirstResponder == true
		let isHighlighted = state.isHighlighted && !isExpanded
		if state.isHighlighted && !state.isSelected && isExpanded {
			backgroundConfig.backgroundColor = .clear
		}

		switch (isHighlighted || state.isSelected || state.isFocused, traitCollection.userInterfaceIdiom) {
		case _ where isActiveSelection:
			backgroundConfig.backgroundColor = Assets.Colors.primaryAccent
			folderTitle.textColor = .white
			folderTitle.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
			unreadCountLabel.textColor = .white
			unreadCountLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
			faviconView.tintColor = .white
			disclosureButton.configuration?.baseForegroundColor = .white
		case (true, .pad):
			backgroundConfig.backgroundColor = .tertiarySystemFill
			folderTitle.textColor = Assets.Colors.primaryAccent
			folderTitle.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
			unreadCountLabel.textColor = Assets.Colors.primaryAccent
			unreadCountLabel.font = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .semibold)
			faviconView.tintColor = Assets.Colors.primaryAccent
			disclosureButton.configuration?.baseForegroundColor = .label
		default:
			folderTitle.textColor = .label
			faviconView.tintColor = Assets.Colors.primaryAccent
			folderTitle.font = UIFont.preferredFont(forTextStyle: .body)
			unreadCountLabel.textColor = .secondaryLabel
			unreadCountLabel.font = UIFont.preferredFont(forTextStyle: .body)
			disclosureButton.configuration?.baseForegroundColor = .label
		}

		if state.cellDropState == .targeted {
			backgroundConfig.backgroundColor = .tertiarySystemFill
		}

		self.backgroundConfiguration = backgroundConfig
	}
}
