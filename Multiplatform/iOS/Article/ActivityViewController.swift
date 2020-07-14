//
//  ArticleShareView.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/13/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import SwiftUI
import Articles

extension UIActivityViewController {
	convenience init(url: URL, title: String?, applicationActivities: [UIActivity]?) {
		let itemSource = ArticleActivityItemSource(url: url, subject: title)
		let titleSource = TitleActivityItemSource(title: title)
		self.init(activityItems: [titleSource, itemSource], applicationActivities: applicationActivities)
	}
}

struct ActivityViewController: UIViewControllerRepresentable {

	var title: String?
	var url: URL

	func makeUIViewController(context: Context) -> UIActivityViewController {
		return UIActivityViewController(url: url, title: title, applicationActivities: [FindInArticleActivity(), OpenInSafariActivity()])
	}

	func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
	}

}
