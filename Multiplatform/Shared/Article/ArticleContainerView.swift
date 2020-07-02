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
	var article: Article? = nil
	
	@ViewBuilder var body: some View {
		if let article = article {
			ArticleView()
				.environmentObject(articleModel)
				.onAppear {
					sceneModel.articleModel = articleModel
					articleModel.delegate = sceneModel
				}
		} else {
			EmptyView()
		}
	}
	
}
