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
	private var queue = NSMutableArray()
	
	init(coordinator: SceneCoordinator) {
		articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init()
		replenishQueueIfNeeded()
	}

	func replenishQueueIfNeeded() {
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
	}
	
	func dequeueWebView(completion: @escaping (PreloadedWebView) -> ()) {
		operationQueue.add(WebViewProviderDequeueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler, completion: completion))
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
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

	private var queue: NSMutableArray
	private var articleIconSchemeHandler: ArticleIconSchemeHandler
	
	init(queue: NSMutableArray, articleIconSchemeHandler: ArticleIconSchemeHandler) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
	}
	
	func run() {
		while queue.count < minimumQueueDepth {
			let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
			webView.preload()
			queue.insert(webView, at: 0)
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

	private var queue: NSMutableArray
	private var articleIconSchemeHandler: ArticleIconSchemeHandler
	private var completion: (PreloadedWebView) -> ()
	
	init(queue: NSMutableArray, articleIconSchemeHandler: ArticleIconSchemeHandler, completion: @escaping (PreloadedWebView) -> ()) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
		self.completion = completion
	}
	
	func run() {
		if let webView = queue.lastObject as? PreloadedWebView {
			self.completion(webView)
			self.queue.remove(webView)
			self.operationDelegate?.operationDidComplete(self)
			return
		}

		assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")
		
		let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
		webView.preload()
		self.completion(webView)
		self.operationDelegate?.operationDidComplete(self)
	}
	
}
