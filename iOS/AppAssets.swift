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

	static var barBackgroundColor: UIColor = {
		return UIColor(named: "barBackgroundColor")!
	}()

	static var barTintColor: UIColor = {
		return UIColor(named: "barTintColor")!
	}()

	static var barTitleColor: UIColor = {
		return UIColor(named: "barTitleColor")!
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
		return image.withTintColor(AppAssets.chevronDisclosureColor, renderingMode: .alwaysOriginal)
	}()
	
	static var chevronRightImage: UIImage = {
		let image = UIImage(systemName: "chevron.right")!
		return image.withTintColor(AppAssets.chevronDisclosureColor, renderingMode: .alwaysOriginal)
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
	
	static var feedImage: RSImage = {
		return RSImage(named: "feedImage")!
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
	
	static var netNewsWireBlueColor: UIColor = {
		return UIColor(named: "netNewsWireBlueColor")!
	}()
	
	static var openInSidebarImage: UIImage = {
		return UIImage(systemName: "arrow.turn.down.left")!
	}()
	
	static var safariImage: UIImage = {
		return UIImage(systemName: "safari")!
	}()
	
	static var selectedTextColor: UIColor = {
		return UIColor(named: "selectedTextColor")!
	}()

	static var settingsImage: UIImage = {
		return UIImage(named: "settingsImage")!
	}()
	
	static var shareImage: UIImage = {
		return UIImage(systemName: "square.and.arrow.up")!
	}()
	
	static var smartFeedColor: UIColor = {
		return UIColor(named: "smartFeedColor")!
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
	
	static var timelineStarImage: UIImage = {
		let image = UIImage(systemName: "star.fill")!
		return image.withTintColor(AppAssets.starColor, renderingMode: .alwaysOriginal)
	}()
	
	static var timelineUnreadCircleColor: UIColor = {
		return UIColor(named: "timelineUnreadCircleColor")!
	}()
	
	static var trashImage: UIImage = {
		return UIImage(systemName: "trash")!
	}()
	
}
