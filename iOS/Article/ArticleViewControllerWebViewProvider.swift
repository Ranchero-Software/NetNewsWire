//
//  ArticleViewControllerWebViewProvider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're past the flash-to-shite part of their lifecycle.
class ArticleViewControllerWebViewProvider: NSObject, WKNavigationDelegate {
	
	static let shared = ArticleViewControllerWebViewProvider()
	
	private let minimumQueueDepth = 3
	private let maximumQueueDepth = 6
	private var queue: [WKWebView] = []
	
	private var waitingForFirstLoad = true
	private var waitingCompletionHandler: ((WKWebView) -> ())?

	func dequeueWebView(completion: @escaping (WKWebView) -> ()) {
		if waitingForFirstLoad {
			waitingCompletionHandler = completion
		} else {
			completeRequest(completion: completion)
		}
	}
	
	func enqueueWebView(_ webView: WKWebView) {
		guard queue.count < maximumQueueDepth else {
			return
		}

		webView.navigationDelegate = self
		queue.insert(webView, at: 0)

		webView.loadHTMLString(ArticleRenderer.page.html, baseURL: ArticleRenderer.page.baseURL)

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

	private override init() {
		super.init()
		replenishQueueIfNeeded()
	}

	private func replenishQueueIfNeeded() {
		while queue.count < minimumQueueDepth {
			let preferences = WKPreferences()
			preferences.javaScriptCanOpenWindowsAutomatically = false
			preferences.javaScriptEnabled = true

			let configuration = WKWebViewConfiguration()
			configuration.preferences = preferences
			configuration.allowsInlineMediaPlayback = true
			configuration.mediaTypesRequiringUserActionForPlayback = .video
			
			let webView = WKWebView(frame: .zero, configuration: configuration)
			enqueueWebView(webView)
		}
	}
	
	private func completeRequest(completion: @escaping (WKWebView) -> ()) {
		if let webView = queue.popLast() {
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
