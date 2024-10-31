//
//  AppAsset-iOS.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 10/30/24.
//  Copyright © 2024 Ranchero Software. All rights reserved.
//

import Foundation

extension AppAsset {
	
	static let starClosedImage = UIImage(systemName: "star.fill")!

	static let searchFeedImage: IconImage = {
		IconImage(UIImage(systemName: "magnifyingglass")!, isSymbol: true)
	}()

	static let unreadFeedImage: IconImage = {
		let image = UIImage(systemName: "largecircle.fill.circle")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)
	}()

	static let todayFeedImage: IconImage = {
		let image = UIImage(systemName: "sun.max.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: UIColor.systemOrange.cgColor)
	}()

	static let starredFeedImage: IconImage = {
		let image = UIImage(systemName: "star.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAsset.starColor.cgColor)
	}()

	static let folderIcon: IconImage = {
		let image = RSImage.systemImage("folder.fill")
		let preferredColor = AppAssets.secondaryAccentColor
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: preferredColor.cgColor)
	}()
}
