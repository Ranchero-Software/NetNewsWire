//
//  UISplitViewController-Extensions.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/18/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

extension UISplitViewController {
	
	static func template() -> UISplitViewController {
		let splitViewController = UISplitViewController()
		splitViewController.preferredDisplayMode = .allVisible

		let navController = UINavigationController()
		navController.isToolbarHidden = false
		splitViewController.viewControllers = [navController]
		
		return splitViewController
	}
	
	func toggleMasterView() {
		let barButtonItem = self.displayModeButtonItem
		if let action = barButtonItem.action {
			UIApplication.shared.sendAction(action, to: barButtonItem.target, from: nil, for: nil)
		}
	}
	
}
