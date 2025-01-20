//
//  ArticleIconSchemeHandler.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/20/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

protocol ArticleIconSchemeHandlerDelegate: AnyObject {
	func articleIconSchemeHandler(_: ArticleIconSchemeHandler, imageForArticleID: String) -> IconImage?
}

final class ArticleIconSchemeHandler: NSObject, WKURLSchemeHandler {

	private weak var delegate: ArticleIconSchemeHandlerDelegate?
	private static let headerFields = ["Cache-Control": "no-cache"]

	init(delegate: ArticleIconSchemeHandlerDelegate) {
		self.delegate = delegate
	}

	// WKURLSchemeHandler is @MainActor, so this is @MainActor.

	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {

		guard let url = urlSchemeTask.request.url,
			  let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			assertionFailure("Expected URL and components in ArticleIconSchemeHandler.")
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		let articleID = components.path
		guard !articleID.isEmpty else {
			assertionFailure("Expected non-empty articleID in ArticleIconSchemeHandler.")
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		guard let iconImage = delegate?.articleIconSchemeHandler(self, imageForArticleID: articleID) else {
			// There may not be an image — this is not a programming error.
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		let iconView = IconView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
		iconView.iconImage = iconImage
		let renderedImage = iconView.asImage()

		guard let data = renderedImage.dataRepresentation() else {
			assertionFailure("Expected non-empty image data ArticleIconSchemeHandler.")
			urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
			return
		}

		guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: Self.headerFields) else {
			assertionFailure("Expected to create HTTPURLResponse but failed.")
			urlSchemeTask.didFailWithError(URLError(.unknown))
			return
		}

		urlSchemeTask.didReceive(response)
		urlSchemeTask.didReceive(data)
		urlSchemeTask.didFinish()
	}

	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
		urlSchemeTask.didFailWithError(URLError(.unknown))
	}
}

// TODO: The above code is re-rendering images multiple times, which is not good
// for performance. Fixing this will probably require some refactoring
// of the entire system for images, so that the code gets some kind of identifier —
// probably a URL — so that it has a key for a cache, so it doesn’t have to
// re-render images.
