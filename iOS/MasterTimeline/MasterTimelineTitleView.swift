//
//  MasterFeedTitleView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterTimelineTitleView: UIView {

	@IBOutlet weak var iconView: IconView!
	@IBOutlet weak var label: UILabel!
	@IBOutlet weak var unreadCountView: MasterTimelineUnreadCountView!

	@available(iOS 13.4, *)
	private lazy var pointerInteraction: UIPointerInteraction = {
		UIPointerInteraction(delegate: self)
	}()

	override var accessibilityLabel: String? {
		set { }
		get {
			if let name = label.text {
				let unreadLabel = NSLocalizedString("UNREAD_LOWERCASE", comment: "Unread label for accessiblity")
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

extension MasterTimelineTitleView: UIPointerInteractionDelegate {
	
	@available(iOS 13.4, *)
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		var rect = self.frame
		rect.origin.x = rect.origin.x - 10
		rect.size.width = rect.width + 20

		return UIPointerStyle(effect: .automatic(UITargetedPreview(view: self)), shape: .roundedRect(rect))
	}
	
}
