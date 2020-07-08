//
//  ArticleView.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

final class ArticleView: NSViewControllerRepresentable {
	
	var sceneModel: SceneModel
	var articleModel: ArticleModel
	var article: Article
	
	init(sceneModel: SceneModel, articleModel: ArticleModel, article: Article) {
		self.sceneModel = sceneModel
		self.articleModel = articleModel
		self.article = article
		sceneModel.articleModel = articleModel
		articleModel.delegate = sceneModel
	}
	
	func makeNSViewController(context: Context) -> WebViewController {
		let controller = WebViewController()
		controller.articleModel = articleModel
		controller.article = article
		return controller
	}
	
	func updateNSViewController(_ uiViewController: WebViewController, context: Context) {
		
	}
	
}
