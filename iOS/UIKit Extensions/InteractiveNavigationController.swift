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
		poppableDelegate.originalDelegate = interactivePopGestureRecognizer?.delegate
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
		
		let navigationAppearance = UINavigationBarAppearance()
		navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
		navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
		navigationBar.standardAppearance = navigationAppearance
		navigationBar.tintColor = AppAssets.primaryAccentColor
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = toolbarAppearance
		toolbar.tintColor = AppAssets.primaryAccentColor
	}

}
