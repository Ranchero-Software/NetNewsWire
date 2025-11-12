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
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're past the flash-to-white part of their lifecycle.
final class WebViewProvider: NSObject {
	private let articleIconSchemeHandler: ArticleIconSchemeHandler
	private let operationQueue = MainThreadOperationQueue()
	private var queue = NSMutableArray()

	@MainActor init(coordinator: SceneCoordinator) {
		articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init()
		replenishQueueIfNeeded()
	}

	@MainActor func replenishQueueIfNeeded() {
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
	}

	@MainActor func dequeueWebView(completion: @escaping (PreloadedWebView) -> ()) {
		operationQueue.add(WebViewProviderDequeueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler, completion: completion))
		operationQueue.add(WebViewProviderReplenishQueueOperation(queue: queue, articleIconSchemeHandler: articleIconSchemeHandler))
	}
}

final class WebViewProviderReplenishQueueOperation: MainThreadOperation, @unchecked Sendable {
	private let minimumQueueDepth = 3

	private var queue: NSMutableArray
	private var articleIconSchemeHandler: ArticleIconSchemeHandler

	@MainActor init(queue: NSMutableArray, articleIconSchemeHandler: ArticleIconSchemeHandler) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
		super.init(name: "WebViewProviderReplenishQueueOperation")
	}

	@MainActor override func run() {
		while queue.count < minimumQueueDepth {
			let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
			webView.preload()
			queue.insert(webView, at: 0)
		}
		didComplete()
	}
}

final class WebViewProviderDequeueOperation: MainThreadOperation, @unchecked Sendable {
	private var queue: NSMutableArray
	private var articleIconSchemeHandler: ArticleIconSchemeHandler
	private var completion: (PreloadedWebView) -> ()

	init(queue: NSMutableArray, articleIconSchemeHandler: ArticleIconSchemeHandler, completion: @escaping (PreloadedWebView) -> ()) {
		self.queue = queue
		self.articleIconSchemeHandler = articleIconSchemeHandler
		self.completion = completion
		super.init(name: "WebViewProviderFlushQueueOperation")
	}

	@MainActor override func run() {
		if let webView = queue.lastObject as? PreloadedWebView {
			self.completion(webView)
			self.queue.remove(webView)
			didComplete()
			return
		}

		assertionFailure("Creating PreloadedWebView in \(#function); queue has run dry.")

		let webView = PreloadedWebView(articleIconSchemeHandler: articleIconSchemeHandler)
		webView.preload()
		self.completion(webView)
		didComplete()
	}
}
