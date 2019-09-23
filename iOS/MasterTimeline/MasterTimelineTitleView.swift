//
//  MasterFeedTitleView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class MasterTimelineTitleView: UIView {

	@IBOutlet weak var imageView: UIImageView! {
		didSet {
			if let imageView = imageView {
				imageView.layer.cornerRadius = 2
				imageView.clipsToBounds = true
			}
		}
	}

	@IBOutlet weak var label: UILabel!
	
}
