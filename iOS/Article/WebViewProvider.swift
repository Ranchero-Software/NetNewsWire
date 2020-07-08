//
//  WebViewProvider.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 9/21/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import Foundation
import RSCore
import WebKit

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're past the flash-to-shite part of their lifecycle.
class WebViewProvider: NSObject {
	
	private let articleIconSchemeHandler: ArticleIconSchemeHandler
	private let operationQueue = MainThreadOperationQueue()
	private var queue = UIView()
	
	init(coordinator: SceneCoordinator, viewController: UIViewController) {
		articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init()
		viewController.view.insertSubview(queue, at: 0)
		replenishQueueIfNeeded()
	}
	
	func flushQueue() {
		operationQueue.add(WebViewProviderFlushQueueOperation(queue: queue))
	}

	func replenishQueueIfNeeded() {
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
	}
	
	func dequeueWebView(completion: @escaping (PreloadedWebView) -> ()) {
		operationQueue.add(WebViewProviderDequeueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler, completion: completion))
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
	}
	
}

class WebViewProviderFlushQueueOperation: MainThreadOperation {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "WebViewProviderFlushQueueOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private var queue: UIView
	
	init(queue: UIView) {
		self.queue = queue
	}
	
	func run() {
		queue.subviews.forEach { $0.removeFromSuperview() }
		self.operationDelegate?.operationDidComplete(self)
	}
	
}

class WebViewProviderReplenishQueueOperation: MainThreadOperation {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "WebViewProviderReplenishQueueOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private let minimumQueueDepth = 3

	private var queue: UIView
	private var articleIconSchemeHandler: ArticleIconSchemeHandler
	
	init(queue: UIView, articleIconSchemeHandler: ArticleIconSchemeHandler) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
	}
	
	func run() {
		while queue.subviews.count < minimumQueueDepth {
			let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
			queue.insertSubview(webView, at: 0)
			webView.preload()
		}
		self.operationDelegate?.operationDidComplete(self)
	}
	
}

class WebViewProviderDequeueOperation: MainThreadOperation {
	
	// MainThreadOperation
	public var isCanceled = false
	public var id: Int?
	public weak var operationDelegate: MainThreadOperationDelegate?
	public var name: String? = "WebViewProviderFlushQueueOperation"
	public var completionBlock: MainThreadOperation.MainThreadOperationCompletionBlock?

	private var queue: UIView
	private var articleIconSchemeHandler: ArticleIconSchemeHandler
	private var completion: (PreloadedWebView) -> ()
	
	init(queue: UIView, articleIconSchemeHandler: ArticleIconSchemeHandler, completion: @escaping (PreloadedWebView) -> ()) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
		self.completion = completion
	}
	
	func run() {
		if let webView = queue.subviews.last as? PreloadedWebView {
			webView.ready { preloadedWebView in
				preloadedWebView.removeFromSuperview()
				self.completion(preloadedWebView)
			}
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")
		
		let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
		webView.preload()
		webView.ready { preloadedWebView in
			self.completion(preloadedWebView)
		}
		self.operationDelegate?.operationDidComplete(self)
	}
	
}
