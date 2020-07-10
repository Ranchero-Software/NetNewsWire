//
//  ArticleView.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

final class ArticleView: UIViewControllerRepresentable {
	
	var sceneModel: SceneModel
	var article: Article
	
	init(sceneModel: SceneModel, article: Article) {
		self.sceneModel = sceneModel
		self.article = article
	}
	
	func makeUIViewController(context: Context) -> ArticleViewController {
		let controller = ArticleViewController()
		sceneModel.articleManager = controller
		controller.sceneModel = sceneModel
		controller.currentArticle = article
		return controller
	}
	
	func updateUIViewController(_ uiViewController: ArticleViewController, context: Context) {
		
	}
	
}
