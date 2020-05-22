//
//  TitleActivityItemSource.swift
//  NetNewsWire-iOS
//
//  Created by Martin Hartl on 01/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

class TitleActivityItemSource: NSObject, UIActivityItemSource {

	private let title: String?

	init(title: String?) {
		self.title = title
	}

	func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
		return title as Any
	}

	func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
		guard let activityType = activityType,
			let title = title else {
				return NSNull()
		}

		switch activityType.rawValue {
		case "com.omnigroup.OmniFocus3.iOS.QuickEntry",
			 "com.culturedcode.ThingsiPhone.ShareExtension",
			 "com.tapbots.Tweetbot4.shareextension",
			 "com.buffer.buffer.Buffer":
			return title
		default:
			return NSNull()
		}
	}
	
}
