//
//  NonIntrinsicImageView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 4/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class NonIntrinsicImageView: UIImageView {

	// Prevent autolayout from messing around with our frame settings
	override var intrinsicContentSize: CGSize {
		return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
	}

}
