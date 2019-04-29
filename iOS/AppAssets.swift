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

	static var circleClosedImage: RSImage = {
		return RSImage(named: "circleClosedImage")!
	}()
	
	static var circleOpenImage: RSImage = {
		return RSImage(named: "circleOpenImage")!
	}()
	
	static var chevronDisclosureColor: UIColor = {
		return UIColor(named: "chevronDisclosureColor")!
	}()
	
	static var chevronDownImage: RSImage = {
		let image = RSImage(named: "chevronDownImage")!
		return image.maskWithColor(color: AppAssets.chevronDisclosureColor)!
	}()
	
	static var chevronRightImage: RSImage = {
		let image = RSImage(named: "chevronRightImage")!
		return image.maskWithColor(color: AppAssets.chevronDisclosureColor)!
	}()
	
	static var faviconTemplateImage: RSImage = {
		return RSImage(named: "faviconTemplateImage")!
	}()
	
	static var feedColor: UIColor = {
		return UIColor(named: "feedColor")!
	}()

	static var feedImage: RSImage = {
		let image = RSImage(named: "feedImage")!
		return image.maskWithColor(color: AppAssets.feedColor)!
	}()
	
	static var masterFolderColor: UIColor = {
		return UIColor(named: "masterFolderColor")!
	}()
	
	static var masterFolderImage: RSImage = {
		let image = RSImage(named: "folderImage")!
		return image.maskWithColor(color: AppAssets.masterFolderColor)!
	}()
	
	static var selectionBackgroundColor: UIColor = {
		return UIColor(named: "selectionBackgroundColor")!
	}()
	
	static var smartFeedColor: UIColor = {
		return UIColor(named: "smartFeedColor")!
	}()
	
	static var smartFeedImage: RSImage = {
		let image = RSImage(named: "smartFeedImage")!
		return image.maskWithColor(color: AppAssets.smartFeedColor)!
	}()
	
	static var starColor: UIColor = {
		return UIColor(named: "starColor")!
	}()
	
	static var starClosedImage: RSImage = {
		return RSImage(named: "starClosedImage")!
	}()
	
	static var starOpenImage: RSImage = {
		return RSImage(named: "starOpenImage")!
	}()
	
	static var timelineStarImage: RSImage = {
		let image = RSImage(named: "starClosedImage")!
		return image.maskWithColor(color: AppAssets.starColor)!
	}()

	static var timelineTextPrimaryColor: UIColor = {
		return UIColor(named: "timelineTextPrimaryColor")!
	}()

	static var timelineTextSecondaryColor: UIColor = {
		return UIColor(named: "timelineTextSecondaryColor")!
	}()

	static var timelineUnreadCircleColor: UIColor = {
		return UIColor(named: "timelineUnreadCircleColor")!
	}()
	
}
