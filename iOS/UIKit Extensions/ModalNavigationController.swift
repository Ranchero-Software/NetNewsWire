//
//  ModalNavigationController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/16/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ModalNavigationController: UINavigationController {

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		
		// This hack is to resolve https://github.com/brentsimmons/NetNewsWire/issues/1301
		let frame = navigationBar.frame
		navigationBar.frame = CGRect(x: frame.minX, y: frame.minY, width: frame.size.width, height: 64.0)
	}
	
}
