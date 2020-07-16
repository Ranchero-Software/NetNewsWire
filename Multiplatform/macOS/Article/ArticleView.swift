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
	
	@EnvironmentObject private var sceneModel: SceneModel
	
	func makeNSViewController(context: Context) -> WebViewController {
		let controller = WebViewController()
		controller.sceneModel = sceneModel
		return controller
	}
	
	func updateNSViewController(_ controller: WebViewController, context: Context) {
	}
	
}
