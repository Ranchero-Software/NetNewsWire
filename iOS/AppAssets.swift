//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
import UIKit
import RSCore
import Account

struct AppAssets {
	static let nnwFeedIcon = RSImage(named: "nnwFeedIcon")!
	static let articleExtractorError = RSImage(named: "articleExtractorError")!
	static let articleExtractorOff = RSImage(named: "articleExtractorOff")!
	static let articleExtractorOffSF = RSImage(systemName: "doc.plaintext")!

	@MainActor static let articleExtractorOffTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOff")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static let articleExtractorOn = RSImage(named: "articleExtractorOn")!
	static let articleExtractorOnSF = RSImage(named: "articleExtractorOnSF")!

	@MainActor static let articleExtractorOnTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOn")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static let iconBackgroundColor = UIColor(named: "iconBackgroundColor")!

	static let circleClosedImage = RSImage(systemName: "largecircle.fill.circle")!
	static let circleOpenImage = RSImage(systemName: "circle")!
	static let disclosureImage = RSImage(named: "disclosure")!
	static let copyImage = RSImage(systemName: "doc.on.doc")!
	static let deactivateImage = RSImage(systemName: "minus.circle")!
	static let editImage = RSImage(systemName: "square.and.pencil")!
	static let faviconTemplateImage = RSImage(named: "faviconTemplateImage")!
	static let filterImage = RSImage(systemName: "line.3.horizontal.decrease")!
	static let folderOutlinePlus = RSImage(systemName: "folder.badge.plus")!
	static let fullScreenBackgroundColor = UIColor(named: "fullScreenBackgroundColor")!
	static let infoImage = RSImage(systemName: "info.circle")!
	static let markAllAsReadImage = RSImage(named: "markAllAsRead")!
	static let markBelowAsReadImage = RSImage(systemName: "arrowtriangle.down.circle")!
	static let markAboveAsReadImage = RSImage(systemName: "arrowtriangle.up.circle")!

	static let mainFolderImage = IconImage(RSImage(systemName: "folder")!, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)

	static let mainFolderImageNonIcon = RSImage(systemName: "folder")!.withRenderingMode(.alwaysOriginal).withTintColor(.secondaryLabel)
	static let moreImage = RSImage(systemName: "ellipsis.circle")!
	static let nextArticleImage = RSImage(systemName: "chevron.down")!
	static let nextUnreadArticleImage = RSImage(systemName: "chevron.down.circle")!
	static let plus = RSImage(systemName: "plus")!
	static let prevArticleImage = RSImage(systemName: "chevron.up")!
	static let openInSidebarImage = RSImage(systemName: "arrow.turn.down.left")!
	static let primaryAccentColor = UIColor(named: "primaryAccentColor")!
	static let safariImage = RSImage(systemName: "safari")!
	static let searchFeedImage = IconImage(UIImage(systemName: "magnifyingglass")!, isSymbol: true)
	static let secondaryAccentColor = UIColor(named: "secondaryAccentColor")!
	static let sectionHeaderColor = UIColor(named: "sectionHeaderColor")!
	static let shareImage = RSImage(systemName: "square.and.arrow.up")!
	static let smartFeedImage = RSImage(systemName: "gear")!
	static let starColor = UIColor(named: "starColor")!

	static let starredFeedImage: IconImage = {
		let image = UIImage(systemName: "star.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppAssets.starColor.cgColor)
	}()

	static let tickMarkColor = UIColor(named: "tickMarkColor")!

	static let timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	}()

	static let todayFeedImage: IconImage = {
		let image = UIImage(systemName: "sun.max.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: UIColor.systemOrange.cgColor)
	}()

	static let trashImage = RSImage(systemName: "trash")!
	static let unreadCellIndicatorImage: IconImage = {
		let image = UIImage(systemName: "circle.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)
	}()

	static let unreadFeedImage: IconImage = {
		let image = UIImage(systemName: "largecircle.fill.circle")!
		return IconImage(image, isSymbol: true, isBackgroundSuppressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)
	}()

	static let vibrantTextColor = UIColor(named: "vibrantTextColor")!
	static let controlBackgroundColor = UIColor(named: "controlBackgroundColor")!
}
