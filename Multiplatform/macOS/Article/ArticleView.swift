//
//  ArticleView.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

struct ArticleView: NSViewControllerRepresentable {
	
	var sceneModel: SceneModel
	var articles: [Article]
	
	func makeNSViewController(context: Context) -> WebViewController {
		let controller = WebViewController()
		controller.sceneModel = sceneModel
		controller.articles = articles
		return controller
	}
	
	func updateNSViewController(_ uiViewController: WebViewController, context: Context) {
		
	}
	
}
