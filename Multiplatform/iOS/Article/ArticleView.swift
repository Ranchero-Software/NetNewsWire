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
	var articleModel: ArticleModel
	var article: Article
	
	init(sceneModel: SceneModel, articleModel: ArticleModel, article: Article) {
		self.sceneModel = sceneModel
		self.articleModel = articleModel
		self.article = article
		sceneModel.articleModel = articleModel
		articleModel.delegate = sceneModel
	}
	
	func makeUIViewController(context: Context) -> ArticleViewController {
		let controller = ArticleViewController()
		controller.articleModel = articleModel
		controller.article = article
		return controller
	}
	
	func updateUIViewController(_ uiViewController: ArticleViewController, context: Context) {
		
	}
	
}
