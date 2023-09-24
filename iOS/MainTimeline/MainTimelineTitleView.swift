//
//  MasterFeedTitleView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

@MainActor final class MainTimelineTitleView: UIView {

	@IBOutlet weak var iconView: IconView!
	@IBOutlet weak var label: UILabel!
	@IBOutlet weak var unreadCountView: MainTimelineUnreadCountView!

	private lazy var pointerInteraction: UIPointerInteraction = {
		UIPointerInteraction(delegate: self)
	}()

	override var accessibilityLabel: String? {
		set { }
		get {
			if let name = label.text {
				let unreadLabel = NSLocalizedString("label.accessibility.unread", comment: "unread")
				return "\(name) \(unreadCountView.unreadCount) \(unreadLabel)"
			}
			else {
				return nil
			}
		}
	}

	func buttonize() {
		heightAnchor.constraint(equalToConstant: 40.0).isActive = true
		accessibilityTraits = .button
		addInteraction(pointerInteraction)
	}
	
	func debuttonize() {
		heightAnchor.constraint(equalToConstant: 40.0).isActive = true
		accessibilityTraits.remove(.button)
		removeInteraction(pointerInteraction)
	}
	
}

extension MainTimelineTitleView: UIPointerInteractionDelegate {
	
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		var rect = self.frame
		rect.origin.x = rect.origin.x - 10
		rect.size.width = rect.width + 20

		return UIPointerStyle(effect: .automatic(UITargetedPreview(view: self)), shape: .roundedRect(rect))
	}
	
}
