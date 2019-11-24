//
//  CroppingPreviewParameters.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/23/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class CroppingPreviewParameters: UIPreviewParameters {
	
	init(view: UIView) {
		super.init()
		let newBounds = CGRect(x: 1, y: 1, width: view.bounds.width - 2, height: view.bounds.height - 2)
		let visiblePath = UIBezierPath(roundedRect: newBounds, cornerRadius: 10)
		self.visiblePath = visiblePath
	}

	init(view: UIView, size: CGSize) {
		super.init()
		let newBounds = CGRect(x: 0, y: 0, width: size.width, height: size.height)
		let visiblePath = UIBezierPath(roundedRect: newBounds, cornerRadius: 10)
		self.visiblePath = visiblePath
	}

}
