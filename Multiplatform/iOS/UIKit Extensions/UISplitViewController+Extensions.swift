//
//  UISplitViewController+Extensions.swift
//  Multiplatform iOS
//
//  Created by Stuart Breckenridge on 15/6/21.
//  Copyright © 2021 Ranchero Software. All rights reserved.
//

import UIKit

extension UISplitViewController {
	
	override open func viewDidLoad() {
		preferredDisplayMode = .twoBesideSecondary // make the sidebar visible on launch.
	}
	
}
