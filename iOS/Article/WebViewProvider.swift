//
//  WebViewProvider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're past the flash-to-shite part of their lifecycle.
class WebViewProvider: NSObject, WKNavigationDelegate {
	
	let articleIconSchemeHandler: ArticleIconSchemeHandler
	
	private let minimumQueueDepth = 3
	private let maximumQueueDepth = 6
	private var queue = UIView()
	
	private var waitingForFirstLoad = true
	private var waitingCompletionHandler: ((WKWebView) -> ())?

	init(coordinator: SceneCoordinator, viewController: UIViewController) {
		articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init()
		viewController.view.insertSubview(queue, at: 0)
		replenishQueueIfNeeded()
	}
	
	func dequeueWebView(completion: @escaping (WKWebView) -> ()) {
		if waitingForFirstLoad {
			waitingCompletionHandler = completion
		} else {
			completeRequest(completion: completion)
		}
	}
	
	func enqueueWebView(_ webView: WKWebView) {
		guard queue.subviews.count < maximumQueueDepth else {
			return
		}

		webView.navigationDelegate = self
		queue.insertSubview(webView, at: 0)

		webView.loadFileURL(ArticleRenderer.page.url, allowingReadAccessTo: ArticleRenderer.page.baseURL)

	}

	// MARK: WKNavigationDelegate
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		if waitingForFirstLoad {
			waitingForFirstLoad = false
			if let completion = waitingCompletionHandler {
				completeRequest(completion: completion)
				waitingCompletionHandler = nil
			}
		}
	}
	
	// MARK: Private

	private func replenishQueueIfNeeded() {
		while queue.subviews.count < minimumQueueDepth {
			let preferences = WKPreferences()
			preferences.javaScriptCanOpenWindowsAutomatically = false
			preferences.javaScriptEnabled = true

			let configuration = WKWebViewConfiguration()
			configuration.preferences = preferences
			configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
			configuration.allowsInlineMediaPlayback = true
			configuration.mediaTypesRequiringUserActionForPlayback = .video
			configuration.setURLSchemeHandler(articleIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
			
			let webView = WKWebView(frame: .zero, configuration: configuration)
			enqueueWebView(webView)
		}
	}
	
	private func completeRequest(completion: @escaping (WKWebView) -> ()) {
		if let webView = queue.subviews.last as? WKWebView {
			webView.removeFromSuperview()
			webView.navigationDelegate = nil
			replenishQueueIfNeeded()
			completion(webView)
			return
		}

		assertionFailure("Creating WKWebView in \(#function); queue has run dry.")
		let webView = WKWebView(frame: .zero)
		completion(webView)
	}
	
}
