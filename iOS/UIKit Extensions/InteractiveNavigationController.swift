//
//  InteractiveNavigationController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class InteractiveNavigationController: UINavigationController {
	
	private let poppableDelegate = PoppableGestureRecognizerDelegate()

	static func template() -> UINavigationController {
		let navController = InteractiveNavigationController()
		navController.configure()
		return navController
	}
	
	static func template(rootViewController: UIViewController) -> UINavigationController {
		let navController = InteractiveNavigationController(rootViewController: rootViewController)
		navController.configure()
		return navController
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		poppableDelegate.navigationController = self
		interactivePopGestureRecognizer?.delegate = poppableDelegate
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
			configure()
		}
	}
		
}

// MARK: Private

private extension InteractiveNavigationController {
	
	func configure() {
		isToolbarHidden = false
		
		let navigationStandardAppearance = UINavigationBarAppearance()
		navigationStandardAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
		navigationStandardAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
		navigationBar.standardAppearance = navigationStandardAppearance
		
		let scrollEdgeStandardAppearance = UINavigationBarAppearance()
		scrollEdgeStandardAppearance.backgroundColor = .systemBackground
		navigationBar.scrollEdgeAppearance = scrollEdgeStandardAppearance
		
		navigationBar.tintColor = AppAssets.primaryAccentColor
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = toolbarAppearance
		toolbar.tintColor = AppAssets.primaryAccentColor
	}

}
