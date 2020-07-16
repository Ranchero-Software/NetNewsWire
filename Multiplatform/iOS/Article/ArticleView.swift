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
	
	@EnvironmentObject private var sceneModel: SceneModel
	
	func makeUIViewController(context: Context) -> ArticleViewController {
		let controller = ArticleViewController()
		controller.sceneModel = sceneModel
		return controller
	}
	
	func updateUIViewController(_ uiViewController: ArticleViewController, context: Context) {
		
	}
	
}
