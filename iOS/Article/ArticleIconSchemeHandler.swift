//
//  AccountViewControllerSchemeHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 11/7/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit
import Articles

class ArticleIconSchemeHandler: NSObject, WKURLSchemeHandler {
	
	var currentArticle: Article?
	
	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		DispatchQueue.main.async {
			guard let responseURL = urlSchemeTask.request.url, let iconImage = self.currentArticle?.iconImage() else {
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
			
			let response = URLResponse(url: responseURL, mimeType: "image/png", expectedContentLength: data.count, textEncodingName: nil);
			urlSchemeTask.didReceive(response)
			urlSchemeTask.didReceive(data)
			urlSchemeTask.didFinish()
		}
	}
	
	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		urlSchemeTask.didFailWithError(URLError(.unknown))
	}
	
}
