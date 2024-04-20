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
	
	static let accountBazQuxImage = UIImage(named: "accountBazQux")!

	static let accountCloudKitImage = UIImage(named: "accountCloudKit")!

	static let accountFeedbinImage = UIImage(named: "accountFeedbin")!

	static let accountFeedlyImage = UIImage(named: "accountFeedly")!

	static let accountFreshRSSImage = UIImage(named: "accountFreshRSS")!

	static let accountInoreaderImage = UIImage(named: "accountInoreader")!

	static let accountLocalPadImage = UIImage(named: "accountLocalPad")!

	static let accountLocalPhoneImage = UIImage(named: "accountLocalPhone")!

	static let accountNewsBlurImage = UIImage(named: "accountNewsBlur")!

	static let accountTheOldReaderImage = UIImage(named: "accountTheOldReader")!

	static let articleExtractorError = UIImage(named: "articleExtractorError")!

	static let articleExtractorOff = UIImage(named: "articleExtractorOff")!

	static let articleExtractorOffSF = UIImage(systemName: "doc.plaintext")!

	@MainActor static let articleExtractorOffTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOff")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static let articleExtractorOn = UIImage(named: "articleExtractorOn")!

	static let articleExtractorOnSF = UIImage(named: "articleExtractorOnSF")!

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

	static let faviconTemplateImage = RSImage(named: "faviconTemplateImage")!

	static let filterInactiveImage = UIImage(systemName: "line.horizontal.3.decrease.circle")!
	
	static let filterActiveImage = UIImage(systemName: "line.horizontal.3.decrease.circle.fill")!

	static let folderOutlinePlus = UIImage(systemName: "folder.badge.plus")!

	static let fullScreenBackgroundColor = UIColor(named: "fullScreenBackgroundColor")!

	static let infoImage = UIImage(systemName: "info.circle")!

	static let markAllAsReadImage = UIImage(named: "markAllAsRead")!

	static let markBelowAsReadImage = UIImage(systemName: "arrowtriangle.down.circle")!

	static let markAboveAsReadImage = UIImage(systemName: "arrowtriangle.up.circle")!

	@MainActor static let folderImage = IconImage(UIImage(systemName: "folder.fill")!, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAssets.secondaryAccentColor.cgColor)

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

	static let shareImage = UIImage(systemName: "square.and.arrow.up")!

	static let smartFeedImage = UIImage(systemName: "gear")!

	static let starColor = UIColor(named: "starColor")!

	static let starClosedImage = UIImage(systemName: "star.fill")!

	static let starOpenImage = UIImage(systemName: "star")!

	@MainActor static let starredFeedImage: IconImage = {
		let image = UIImage(systemName: "star.fill")!
		return IconImage(image, isSymbol: true, isBackgroundSupressed: true, preferredColor: AppAssets.starColor.cgColor)
	}()

	static let tickMarkColor = UIColor(named: "tickMarkColor")!

	static let timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
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

	@MainActor static func image(for accountType: AccountType) -> UIImage? {
		switch accountType {
		case .onMyMac:
			if UIDevice.current.userInterfaceIdiom == .pad {
				return AppAssets.accountLocalPadImage
			} else {
				return AppAssets.accountLocalPhoneImage
			}
		case .cloudKit:
			return AppAssets.accountCloudKitImage
		case .feedbin:
			return AppAssets.accountFeedbinImage
		case .feedly:
			return AppAssets.accountFeedlyImage
		case .freshRSS:
			return AppAssets.accountFreshRSSImage
		case .newsBlur:
			return AppAssets.accountNewsBlurImage
		case .inoreader:
			return AppAssets.accountInoreaderImage
		case .bazQux:
			return AppAssets.accountBazQuxImage
		case .theOldReader:
			return AppAssets.accountTheOldReaderImage
		}
	}
}
