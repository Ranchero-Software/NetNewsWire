//
//  ArticleActivityItemSource.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/13/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
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
		return url
	}
	
	func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
		return subject ?? ""
	}
	
}
