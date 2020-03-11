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
class WebViewProvider: NSObject {
	
	let articleIconSchemeHandler: ArticleIconSchemeHandler
	
	private let minimumQueueDepth = 3
	private let maximumQueueDepth = 6
	private var queue = UIView()
	
	init(coordinator: SceneCoordinator, viewController: UIViewController) {
		articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init()
		viewController.view.insertSubview(queue, at: 0)
		
		replenishQueueIfNeeded()
	}
	
	func flushQueue() {
		queue.subviews.forEach { $0.removeFromSuperview() }
	}

	func replenishQueueIfNeeded() {
		while queue.subviews.count < minimumQueueDepth {
			enqueueWebView(PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler))
		}
	}
	
	func dequeueWebView(completion: @escaping (PreloadedWebView) -> ()) {
		if let webView = queue.subviews.last as? PreloadedWebView {
			webView.ready { preloadedWebView in
				preloadedWebView.removeFromSuperview()
				self.replenishQueueIfNeeded()
				completion(preloadedWebView)
			}
			return
		}

		assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")
		
		let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
		webView.ready { preloadedWebView in
			self.replenishQueueIfNeeded()
			completion(preloadedWebView)
		}
	}
	
	func enqueueWebView(_ webView: PreloadedWebView) {
		guard queue.subviews.count < maximumQueueDepth else {
			return
		}
		queue.insertSubview(webView, at: 0)
		webView.preload()
	}
	
}
