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
	
	func buttonize() {
		heightAnchor.constraint(equalToConstant: 40.0).isActive = true
		accessibilityTraits = .button
		if #available(iOS 13.4, *) {
			addInteraction(pointerInteraction)
		}
	}
	
	func debuttonize() {
		accessibilityTraits.remove(.button)
		if #available(iOS 13.4, *) {
			removeInteraction(pointerInteraction)
		}
	}
	
}

extension MasterTimelineTitleView: UIPointerInteractionDelegate {
	
	@available(iOS 13.4, *)
	func pointerInteraction(_ interaction: UIPointerInteraction, styleFor region: UIPointerRegion) -> UIPointerStyle? {
		
		let params = UIPreviewParameters()
		var rect = self.bounds
		rect.origin.x = rect.origin.x - 10
		rect.size.width = rect.width + 20
		let path = UIBezierPath(roundedRect: rect, cornerRadius: 10.0)
		params.visiblePath = path
		
		let preview = UITargetedPreview(view: self, parameters: params)

		return UIPointerStyle(effect: .automatic(preview), shape: .path(path))
	}
	
}
