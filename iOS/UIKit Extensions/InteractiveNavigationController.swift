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
		
		// Standard appearance with system background
		let standardAppearance = UINavigationBarAppearance()
		standardAppearance.backgroundColor = .clear
		standardAppearance.shadowColor = nil
		
		let scrollEdgeAppearance = UINavigationBarAppearance()
		scrollEdgeAppearance.backgroundColor = .systemBackground
		scrollEdgeAppearance.shadowColor = nil		
		
		navigationBar.standardAppearance = standardAppearance
		navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
		navigationBar.compactAppearance = standardAppearance
		navigationBar.compactScrollEdgeAppearance = scrollEdgeAppearance
		
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbarAppearance.shadowColor = nil
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = nil
		toolbar.scrollEdgeAppearance = nil
		toolbar.tintColor = AppAssets.primaryAccentColor
	}

}
