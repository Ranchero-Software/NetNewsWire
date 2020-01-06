//
//  ArticleActivityItemSource.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/20/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit

class ArticleActivityItemSource: NSObject, UIActivityItemSource {
	
	private let url: URL
	private let subject: String?
	
	init(url: URL, subject: String?) {
		self.url = url
		self.subject = subject
	}
	
	func activityViewControllerPlaceholderItem(_ : UIActivityViewController) -> Any {
		return url
	}
	
	func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
		guard let activityType = activityType,
			let subject = subject else {
				return url
		}

		switch activityType.rawValue {
		case "com.omnigroup.OmniFocus3.iOS.QuickEntry",
			 "com.culturedcode.ThingsiPhone.ShareExtension":
			return "\(subject)\n\(url)"
		default:
			return url
		}
	}
	
	func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
		return subject ?? ""
	}
	
}
