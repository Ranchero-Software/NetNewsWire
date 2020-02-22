//
//  ArticleIconSchemeHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit
import Articles

class ArticleIconSchemeHandler: NSObject, WKURLSchemeHandler {
	
	weak var coordinator: SceneCoordinator?
	
	init(coordinator: SceneCoordinator) {
		self.coordinator = coordinator
	}
	
	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

		guard let url = urlSchemeTask.request.url, let coordinator = coordinator else {
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return
		}
		let articleID = components.path
		guard let iconImage = coordinator.articleFor(articleID)?.iconImage() else {
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		let iconView = IconView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
		iconView.iconImage = iconImage
		let renderedImage = iconView.asImage()
		
		guard let data = renderedImage.dataRepresentation() else {
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}
		
		let headerFields = ["Cache-Control": "no-cache"]
		if let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: headerFields) {
			urlSchemeTask.didReceive(response)
			urlSchemeTask.didReceive(data)
			urlSchemeTask.didFinish()
		}

	}
	
	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		urlSchemeTask.didFailWithError(URLError(.unknown))
	}
	
}

