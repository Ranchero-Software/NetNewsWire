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

	static var avatarBackgroundColor: UIColor = {
		return UIColor(named: "avatarBackgroundColor")!
	}()

	static var circleClosedImage: UIImage = {
		return UIImage(systemName: "circle.fill")!
	}()
	
	static var circleOpenImage: UIImage = {
		return UIImage(systemName: "circle")!
	}()
	
	static var chevronDisclosureColor: UIColor = {
		return UIColor(named: "chevronDisclosureColor")!
	}()
	
	static var chevronDownImage: UIImage = {
		let image = UIImage(systemName: "chevron.down")!
		return image
//		return image.withTintColor(AppAssets.chevronDisclosureColor, renderingMode: .alwaysOriginal)
	}()
	
	static var chevronRightImage: UIImage = {
		let image = UIImage(systemName: "chevron.right")!
		return image
//		return image.withTintColor(AppAssets.chevronDisclosureColor, renderingMode: .alwaysOriginal)
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()
	
	static var feedImage: RSImage = {
		return RSImage(named: "feedImage")!
	}()
	
	static var masterFolderColor: UIColor = {
		return UIColor(named: "masterFolderColor")!
	}()
	
	static var masterFolderImage: UIImage = {
		let image = UIImage(systemName: "folder.fill")!
		return image
//		return image.withTintColor(AppAssets.masterFolderColor, renderingMode: .alwaysOriginal)
	}()
	
	static var netNewsWireBlueColor: UIColor = {
		return UIColor(named: "netNewsWireBlueColor")!
	}()
	
	static var selectedTextColor: UIColor = {
		return UIColor(named: "selectedTextColor")!
	}()

	static var settingsImage: UIImage = {
		return UIImage(named: "settingsImage")!
	}()
	
	static var smartFeedColor: UIColor = {
		return UIColor(named: "smartFeedColor")!
	}()
	
	static var smartFeedImage: UIImage = {
		let image = UIImage(systemName: "gear")!
		return image
//		return image.withTintColor(AppAssets.smartFeedColor, renderingMode: .alwaysOriginal)
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
	
	static var timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image
//		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	}()
	
	static var timelineUnreadCircleColor: UIColor = {
		return UIColor(named: "timelineUnreadCircleColor")!
	}()
	
}
