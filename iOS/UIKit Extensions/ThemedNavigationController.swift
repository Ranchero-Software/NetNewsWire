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
		
		let navigationAppearance = UINavigationBarAppearance()
		let backgroundImage = AppAssets.barBackgroundColor.image()
		navigationAppearance.backgroundImage = backgroundImage
		navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor.label]
		navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.label]
		navigationBar.standardAppearance = navigationAppearance
		navigationBar.tintColor = AppAssets.primaryAccentColor
		
		let toolbarAppearance = UIToolbarAppearance()
		toolbarAppearance.backgroundImage = backgroundImage
		toolbar.standardAppearance = toolbarAppearance
		toolbar.compactAppearance = toolbarAppearance
		toolbar.tintColor = AppAssets.primaryAccentColor
	}
	
}

extension UIColor {
    func image(_ size: CGSize = CGSize(width: 1, height: 1)) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { rendererContext in
            self.setFill()
            rendererContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}
