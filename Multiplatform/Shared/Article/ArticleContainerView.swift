//
//  ArticleContainerView.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 7/2/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import SwiftUI
import Articles

struct ArticleContainerView: View {
	
	@EnvironmentObject private var sceneModel: SceneModel
	@StateObject private var articleModel = ArticleModel()
	var article: Article
	
	@ViewBuilder var body: some View {
		ArticleView()
			.modifier(ArticleToolbarModifier())
			.environmentObject(articleModel)
			.onAppear {
				sceneModel.articleModel = articleModel
				articleModel.delegate = sceneModel
			}
	}
	
}
