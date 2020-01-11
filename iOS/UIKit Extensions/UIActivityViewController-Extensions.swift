//
//  ShareArticleActivityViewController.swift
//  NetNewsWire-iOS
//
//  Created by Martin Hartl on 01/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit

extension UIActivityViewController {
	convenience init(url: URL, title: String?, applicationActivities: [UIActivity]?) {
		let itemSource = ArticleActivityItemSource(url: url, subject: title)
		let titleSource = TitleActivityItemSource(title: title)
		
		self.init(activityItems: [titleSource, itemSource], applicationActivities: applicationActivities)
	}
}
