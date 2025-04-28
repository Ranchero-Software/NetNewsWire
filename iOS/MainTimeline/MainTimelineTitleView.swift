//
//  MainTimelineTitleView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MainTimelineTitleView: UIView {

	@IBOutlet var iconView: IconView?
	@IBOutlet var label: UILabel?
	@IBOutlet var unreadCountView: MainTimelineUnreadCountView?

	@available(iOS 13.4, *)
	private lazy var pointerInteraction: UIPointerInteraction = {
		UIPointerInteraction(delegate: self)
	}()

	override var accessibilityLabel: String? {
		set { }
		get {
			if let name = label?.text {
				let unreadLabel = NSLocalizedString("unread", comment: "Unread label for accessiblity")
				return "\(name) \(unreadCountView?.unreadCount ?? 0) \(unreadLabel)"
			}
			else {
				return nil
			}
		}
	}

	func buttonize() {
		heightAnchor.constraint(equalToConstant: 40.0).isActive = true
		accessibilityTraits = .button
		if #available(iOS 13.4, *) {
			addInteraction(pointerInteraction)
		}
	}
	
	func debuttonize() {
		heightAnchor.constraint(equalToConstant: 40.0).isActive = true
		accessibilityTraits.remove(.button)
		if #available(iOS 13.4, *) {
			removeInteraction(pointerInteraction)
		}
	}
	
}

extension MainTimelineTitleView: UIPointerInteractionDelegate {
	
	@available(iOS 13.4, *)
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		var rect = self.frame
		rect.origin.x = rect.origin.x - 10
		rect.size.width = rect.width + 20

		return UIPointerStyle(effect: .automatic(UITargetedPreview(view: self)), shape: .roundedRect(rect))
	}
	
}
