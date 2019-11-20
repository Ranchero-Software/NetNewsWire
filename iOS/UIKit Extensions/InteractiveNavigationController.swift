//
//  InteractiveNavigationController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 8/22/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

protocol InteractiveNavigationControllerTappable {
	func didTapNavigationBar()
}

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
		
		navigationBar.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar)))
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		super.traitCollectionDidChange(previousTraitCollection)
		if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
			configure()
		}
	}
		
	@objc func didTapNavigationBar() {
		if let tappable = topViewController as? InteractiveNavigationControllerTappable {
			tappable.didTapNavigationBar()
		}
	}
	
}

// MARK: Private

private extension InteractiveNavigationController {
	
	func configure() {
		isToolbarHidden = false
		view.backgroundColor = AppAssets.barBackgroundColor
		
		let navigationAppearance = UINavigationBarAppearance()
		navigationAppearance.backgroundColor = AppAssets.barBackgroundColor
		navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
		navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
		navigationBar.standardAppearance = navigationAppearance
		navigationBar.tintColor = AppAssets.primaryAccentColor
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbarAppearance.backgroundColor = AppAssets.barBackgroundColor
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = toolbarAppearance
		toolbar.tintColor = AppAssets.primaryAccentColor
	}

}
