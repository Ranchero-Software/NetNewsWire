//
//  ThemedNavigationController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ThemedNavigationController: UINavigationController {
	
	static func template() -> UINavigationController {
		let navController = ThemedNavigationController()
		navController.configure()
		return navController
	}
	
	static func template(rootViewController: UIViewController) -> UINavigationController {
		let navController = ThemedNavigationController(rootViewController: rootViewController)
		navController.configure()
		return navController
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
			configure()
		}
	}
		
	private func configure() {
		isToolbarHidden = false
		
		if traitCollection.userInterfaceStyle == .dark {
			navigationBar.standardAppearance = UINavigationBarAppearance()
			navigationBar.tintColor = view.tintColor
			toolbar.standardAppearance = UIToolbarAppearance()
			toolbar.tintColor = view.tintColor
		} else {
			let navigationAppearance = UINavigationBarAppearance()
			navigationAppearance.backgroundColor = AppAssets.barBackgroundColor
			navigationAppearance.titleTextAttributes = [.foregroundColor: AppAssets.barTitleColor]
			navigationAppearance.largeTitleTextAttributes = [.foregroundColor: AppAssets.barTitleColor]
			navigationBar.standardAppearance = navigationAppearance
			navigationBar.tintColor = AppAssets.barTintColor
			
			let toolbarAppearance = UIToolbarAppearance()
			toolbarAppearance.backgroundColor = UIColor.white
			toolbar.standardAppearance = toolbarAppearance
			toolbar.tintColor = AppAssets.barTintColor
		}
		
	}
	
}
