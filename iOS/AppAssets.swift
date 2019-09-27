//
//  AppAssets.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//
import UIKit
import RSCore

struct AppAssets {

	static var articleExtractorError: UIImage = {
		return UIImage(named: "articleExtractorError")!
	}()

	static var articleExtractorOff: UIImage = {
		return UIImage(named: "articleExtractorOff")!
	}()

	static var articleExtractorOffTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOff")!
		return image.maskWithColor(color: AppAssets.primaryAccentColor.cgColor)!
	}()

	static var articleExtractorOn: UIImage = {
		return UIImage(named: "articleExtractorOn")!
	}()

	static var articleExtractorOnTinted: UIImage = {
		let image = UIImage(named: "articleExtractorOn")!
		return image.maskWithColor(color: AppAssets.primaryAccentColor.cgColor)!
	}()

	static var avatarBackgroundColor: UIColor = {
		return UIColor(named: "avatarBackgroundColor")!
	}()

	static var barBackgroundColor: UIColor = {
		return UIColor(named: "barBackgroundColor")!
	}()

	static var circleClosedImage: UIImage = {
		return UIImage(systemName: "largecircle.fill.circle")!
	}()
	
	static var circleOpenImage: UIImage = {
		return UIImage(systemName: "circle")!
	}()
	
	static var chevronSmallImage: UIImage = {
		return UIImage(named: "chevronSmall")!
	}()
	
	static var chevronBaseImage: UIImage = {
		return UIImage(named: "chevronBase")!
	}()
	
	static var copyImage: UIImage = {
		return UIImage(systemName: "doc.on.doc")!
	}()
	
	static var editImage: UIImage = {
		UIImage(systemName: "square.and.pencil")!
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()
	
	static var markAllInFeedAsReadImage: UIImage = {
		return UIImage(systemName: "asterisk.circle")!
	}()
	
	static var markOlderAsReadDownImage: UIImage = {
		return UIImage(systemName: "arrowtriangle.down.circle")!
	}()
	
	static var markOlderAsReadUpImage: UIImage = {
		return UIImage(systemName: "arrowtriangle.up.circle")!
	}()
	
	static var masterFolderImage: UIImage = {
		return UIImage(systemName: "folder.fill")!
	}()
	
	static var moreImage: UIImage = {
		return UIImage(systemName: "ellipsis.circle")!
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
	
	static var searchFeedImage: UIImage = {
		return UIImage(systemName: "magnifyingglass")!
	}()
	
	static var secondaryAccentColor: UIColor = {
		return UIColor(named: "secondaryAccentColor")!
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
	
	static var starredFeedImage: UIImage = {
		return UIImage(systemName: "star.fill")!
	}()

	static var tableViewCellHighlightedTextColor: UIColor = {
		return UIColor(named: "tableViewCellHighlightedTextColor")!
	}()

	static var timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	}()
	
	static var todayFeedImage: UIImage = {
		return UIImage(systemName: "sun.max.fill")!
	}()

	static var trashImage: UIImage = {
		return UIImage(systemName: "trash")!
	}()
	
	static var unreadFeedImage: UIImage = {
		return UIImage(systemName: "largecircle.fill.circle")!
	}()
	
}
