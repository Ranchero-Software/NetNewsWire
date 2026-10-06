//
//  ShareArticleActivityViewController.swift
//  NetNewsWire-iOS
//
//  Created by Martin Hartl on 01/11/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

#if os(iOS)

import UIKit

public extension UIActivityViewController {

	convenience init(url: URL, title: String?, applicationActivities: [UIActivity]?) {
		let itemSource = ArticleActivityItemSource(url: url, subject: title)
		let titleSource = TitleActivityItemSource(title: title)

		// URL source first so the shared item Shortcuts (and other consumers) sees is the article URL.
		// The title source returns NSNull for everything except a few apps, so it must not be first.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/5167>
		self.init(activityItems: [itemSource, titleSource], applicationActivities: applicationActivities)
	}
}

#endif
