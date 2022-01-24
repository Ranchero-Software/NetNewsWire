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
		
		let scrollEdgeStandardAppearance = UINavigationBarAppearance()
		
		scrollEdgeStandardAppearance.shadowColor = nil
		scrollEdgeStandardAppearance.titleTextAttributes = [
			.foregroundColor: UIColor.label,
			.font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize, weight: .heavy)
		]
		scrollEdgeStandardAppearance.largeTitleTextAttributes = [
			.foregroundColor: UIColor.label,
			.font: UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: .largeTitle).pointSize - 3, weight: .black)
		]
		navigationBar.tintColor = AppAssets.primaryAccentColor
		navigationBar.standardAppearance = scrollEdgeStandardAppearance
		navigationBar.isTranslucent = true
		navigationBar.scrollEdgeAppearance = nil
		navigationBar.compactAppearance = nil
		navigationBar.compactScrollEdgeAppearance = nil
		
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbarAppearance.shadowColor = nil
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = toolbarAppearance
		toolbar.tintColor = AppAssets.primaryAccentColor
	}

}
