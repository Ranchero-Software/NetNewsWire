//
//  ArticleIconSchemeHandler.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 1/27/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit
import Images

protocol ArticleIconSchemeHandlerDelegate: AnyObject {
	
	@MainActor func iconImage(for articleID: String) -> IconImage?
}

final class ArticleIconSchemeHandler: NSObject, WKURLSchemeHandler {

	weak var delegate: ArticleIconSchemeHandlerDelegate?

	init(delegate: ArticleIconSchemeHandlerDelegate) {
		self.delegate = delegate
	}
	
	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

		guard let url = urlSchemeTask.request.url, let delegate else {
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return
		}
		let articleID = components.path

		MainActor.assumeIsolated {
			guard let iconImage = delegate.iconImage(for: articleID) else {
				urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
				return
			}

			Task { @MainActor in

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
		}
	}

	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		urlSchemeTask.didFailWithError(URLError(.unknown))
	}
}

