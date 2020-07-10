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
	var article: Article
	
	init(sceneModel: SceneModel, article: Article) {
		self.sceneModel = sceneModel
		self.article = article
	}
	
	func makeNSViewController(context: Context) -> WebViewController {
		let controller = WebViewController()
		sceneModel.articleManager = controller
		controller.sceneModel = sceneModel
		controller.currentArticle = article
		return controller
	}
	
	func updateNSViewController(_ uiViewController: WebViewController, context: Context) {
		
	}
	
}
