//
//  RoundedProgressView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 10/29/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class RoundedProgressView: UIProgressView {

	override func layoutSubviews() {
		super.layoutSubviews()
		subviews.forEach { subview in
			subview.layer.masksToBounds = true
			subview.layer.cornerRadius = bounds.height / 2.0
		}
	}

}
