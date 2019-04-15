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
	
	static var cogImage: RSImage = {
		return RSImage(named: "cogImage")!
	}()
	
	static var feedImage: RSImage = {
		return RSImage(named: "rssImage")!
	}()
	
	static var folderImage: RSImage = {
		return RSImage(named: "folderImage")!
	}()
	
	static var masterFolderColor: UIColor = {
		return UIColor(named: "masterFolderColor")!
	}()
	
	static var masterFolderImage: UIImage = {
		let image = UIImage(named: "folderImage")!
		return image.maskWithColor(color: AppAssets.masterFolderColor)!
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
