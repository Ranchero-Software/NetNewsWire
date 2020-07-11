//
//  ArticleView.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

struct ArticleView: UIViewControllerRepresentable {
	
	var sceneModel: SceneModel
	var articles: [Article]
	
	func makeUIViewController(context: Context) -> ArticleViewController {
		let controller = ArticleViewController()
		controller.sceneModel = sceneModel
		controller.articles = articles
		return controller
	}
	
	func updateUIViewController(_ uiViewController: ArticleViewController, context: Context) {
		
	}
	
}
