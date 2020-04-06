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
	
	static var accountLocalPadImage: UIImage = {
		return UIImage(named: "accountLocalPad")!
	}()

	static var accountLocalPhoneImage: UIImage = {
		return UIImage(named: "accountLocalPhone")!
	}()

	static var accountCloudKitImage: UIImage = {
		return UIImage(named: "accountCloudKit")!
	}()

	static var accountFeedbinImage: UIImage = {
		return UIImage(named: "accountFeedbin")!
	}()

	static var accountFeedlyImage: UIImage = {
		return UIImage(named: "accountFeedly")!
	}()
	
	static var accountFeedWranglerImage: UIImage = {
		return UIImage(named: "accountFeedWrangler")!
	}()

	static var accountFreshRSSImage: UIImage = {
		return UIImage(named: "accountFreshRSS")!
	}()

	static var accountNewsBlurImage: UIImage = {
		return UIImage(named: "accountNewsBlur")!
	}()

	static var articleExtractorError: UIImage = {
		return UIImage(named: "articleExtractorError")!
	}()

	static var articleExtractorOff: UIImage = {
		return UIImage(named: "articleExtractorOff")!
	}()

	static var articleExtractorOffSF: UIImage = {
		return UIImage(systemName: "doc.plaintext")!
	}()

	static var articleExtractorOffTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOff")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static var articleExtractorOn: UIImage = {
		return UIImage(named: "articleExtractorOn")!
	}()

	static var articleExtractorOnSF: UIImage = {
		return UIImage(named: "articleExtractorOnSF")!
	}()

	static var articleExtractorOnTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOn")!
		return image.tinted(color: AppAssets.primaryAccentColor)!
	}()

	static var iconBackgroundColor: UIColor = {
		return UIColor(named: "iconBackgroundColor")!
	}()

	static var circleClosedImage: UIImage = {
		return UIImage(systemName: "largecircle.fill.circle")!
	}()
	
	static var circleOpenImage: UIImage = {
		return UIImage(systemName: "circle")!
	}()
	
	static var disclosureImage: UIImage = {
		return UIImage(named: "disclosure")!
	}()
	
	static var copyImage: UIImage = {
		return UIImage(systemName: "doc.on.doc")!
	}()
	
	static var deactivateImage: UIImage = {
		UIImage(systemName: "minus.circle")!
	}()
	
	static var editImage: UIImage = {
		UIImage(systemName: "square.and.pencil")!
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()
	
	static var filterInactiveImage: UIImage = {
		UIImage(systemName: "line.horizontal.3.decrease.circle")!
	}()
	
	static var filterActiveImage: UIImage = {
		UIImage(systemName: "line.horizontal.3.decrease.circle.fill")!
	}()
	
	static var fullScreenBackgroundColor: UIColor = {
		return UIColor(named: "fullScreenBackgroundColor")!
	}()

	static var infoImage: UIImage = {
		UIImage(systemName: "info.circle")!
	}()
	
	static var markAllAsReadImage: UIImage = {
		return UIImage(named: "markAllAsRead")!
	}()
	
	static var markBelowAsReadImage: UIImage = {
		return UIImage(systemName: "arrowtriangle.down.circle")!
	}()
	
	static var markAboveAsReadImage: UIImage = {
		return UIImage(systemName: "arrowtriangle.up.circle")!
	}()
	
	static var masterFolderImage: IconImage = {
		return IconImage(UIImage(systemName: "folder.fill")!)
	}()
	
	static var moreImage: UIImage = {
		return UIImage(systemName: "ellipsis.circle")!
	}()
	
	static var nextArticleImage: UIImage = {
		return UIImage(systemName: "chevron.down")!
	}()
	
	static var nextUnreadArticleImage: UIImage = {
		return UIImage(systemName: "chevron.down.circle")!
	}()
	
	static var prevArticleImage: UIImage = {
		return UIImage(systemName: "chevron.up")!
	}()
	
	static var openInSidebarImage: UIImage = {
		return UIImage(systemName: "arrow.turn.down.left")!
	}()
	
	static var primaryAccentColor: UIColor = {
		return UIColor(named: "primaryAccentColor")!
	}()
	
	static var safariImage: UIImage = {
		return UIImage(systemName: "safari")!
	}()
	
	static var searchFeedImage: IconImage = {
		return IconImage(UIImage(systemName: "magnifyingglass")!)
	}()
	
	static var secondaryAccentColor: UIColor = {
		return UIColor(named: "secondaryAccentColor")!
	}()
	
	static var sectionHeaderColor: UIColor = {
		return UIColor(named: "sectionHeaderColor")!
	}()
	
	static var shareImage: UIImage = {
		return UIImage(systemName: "square.and.arrow.up")!
	}()
	
	static var smartFeedImage: UIImage = {
		return UIImage(systemName: "gear")!
	}()
	
	static var starColor: UIColor = {
		return UIColor(named: "starColor")!
	}()
	
	static var starClosedImage: UIImage = {
		return UIImage(systemName: "star.fill")!
	}()
	
	static var starOpenImage: UIImage = {
		return UIImage(systemName: "star")!
	}()
	
	static var starredFeedImage: IconImage = {
		return IconImage(UIImage(systemName: "star.fill")!)
	}()

	static var tickMarkColor: UIColor = {
		return UIColor(named: "tickMarkColor")!
	}()
	
	static var timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	}()
	
	static var todayFeedImage: IconImage = {
		return IconImage(UIImage(systemName: "sun.max.fill")!)
	}()

	static var trashImage: UIImage = {
		return UIImage(systemName: "trash")!
	}()
	
	static var unreadFeedImage: IconImage = {
		return IconImage(UIImage(systemName: "largecircle.fill.circle")!)
	}()
	
	static var vibrantTextColor: UIColor = {
		return UIColor(named: "vibrantTextColor")!
	}()

	static var controlBackgroundColor: UIColor = {
		return UIColor(named: "controlBackgroundColor")!
	}()

	static func image(for accountType: AccountType) -> UIImage? {
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
		case .feedWrangler:
			return AppAssets.accountFeedWranglerImage
		case .freshRSS:
			return AppAssets.accountFreshRSSImage
		case .newsBlur:
			return AppAssets.accountNewsBlurImage
		}
	}
	
}
