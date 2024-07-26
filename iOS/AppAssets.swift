//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import Account
import Core
import Images

struct AppAssets {
	
	@MainActor static let articleExtractorOffTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOff")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	@MainActor static let articleExtractorOnTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOn")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static let iconBackgroundColor = UIColor(named: "iconBackgroundColor")!

	static let circleClosedImage = UIImage(systemName: "largecircle.fill.circle")!

	static let circleOpenImage = UIImage(systemName: "circle")!

	static let disclosureImage = UIImage(named: "disclosure")!

	static let copyImage = UIImage(systemName: "doc.on.doc")!

	static let deactivateImage = UIImage(systemName: "minus.circle")!

	static let editImage = UIImage(systemName: "square.and.pencil")!

	static let folderOutlinePlus = UIImage(systemName: "folder.badge.plus")!

	static let fullScreenBackgroundColor = UIColor(named: "fullScreenBackgroundColor")!

	static let infoImage = UIImage(systemName: "info.circle")!

	static let markBelowAsReadImage = UIImage(systemName: "arrowtriangle.down.circle")!

	static let markAboveAsReadImage = UIImage(systemName: "arrowtriangle.up.circle")!

	static let folderImageNonIcon = UIImage(systemName: "folder.fill")!.withRenderingMode(.alwaysOriginal).withTintColor(.secondaryLabel)

	static let moreImage = UIImage(systemName: "ellipsis.circle")!

	static let nextArticleImage = UIImage(systemName: "chevron.down")!
	
	static let nextUnreadArticleImage = UIImage(systemName: "chevron.down.circle")!

	static let plus = UIImage(systemName: "plus")!

	static let prevArticleImage = UIImage(systemName: "chevron.up")!

	static let openInSidebarImage = UIImage(systemName: "arrow.turn.down.left")!

	static let primaryAccentColor = UIColor(named: "primaryAccentColor")!

	static let safariImage = UIImage(systemName: "safari")!

	@MainActor static let searchFeedImage = IconImage(UIImage(systemName: "magnifyingglass")!, isSymbol: true)

	static let secondaryAccentColor = UIColor(named: "secondaryAccentColor")!

	static let sectionHeaderColor = UIColor(named: "sectionHeaderColor")!

	static let smartFeedImage = UIImage(systemName: "gear")!

	static let starClosedImage = UIImage(systemName: "star.fill")!

	static let starOpenImage = UIImage(systemName: "star")!

	@MainActor static let starredFeedImage: IconImage = {
		let image = UIImage(systemName: "star.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAsset.starColor.cgColor)
	}()

	static let tickMarkColor = UIColor(named: "tickMarkColor")!

	static let timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAsset.starColor, renderingMode: .alwaysOriginal)
	}()
	
	@MainActor static let todayFeedImage: IconImage = {
		let image = UIImage(systemName: "sun.max.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: UIColor.systemOrange.cgColor)
	}()

	static let trashImage = UIImage(systemName: "trash")!

	@MainActor static let unreadFeedImage: IconImage = {
		let image = UIImage(systemName: "largecircle.fill.circle")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)
	}()

	static let vibrantTextColor = UIColor(named: "vibrantTextColor")!

	static let controlBackgroundColor = UIColor(named: "controlBackgroundColor")!
}
