//
//  WebViewFullscreenKeeper.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 8/10/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import os

/// Keeps a web view alive while it's in any element-fullscreen state.
/// Deallocating a web view during the enter-fullscreen transition triggers
/// a WebKit RELEASE_ASSERT in WebFullScreenManagerProxy.
/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5382>
@MainActor final class WebViewFullscreenKeeper {

	static let shared = WebViewFullscreenKeeper()

	private var retainedWebViews = [ObjectIdentifier: WKWebView]()

	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "WebViewFullscreenKeeper")

	func updateRetention(for webView: WKWebView) {
		let identifier = ObjectIdentifier(webView)
		let countBefore = retainedWebViews.count

		if webView.fullscreenState == .notInFullscreen {
			retainedWebViews.removeValue(forKey: identifier)
		} else {
			retainedWebViews.updateValue(webView, forKey: identifier)
		}

		Self.logger.debug("WebViewFullscreenKeeper: updateRetention — fullscreenState \(String(describing: webView.fullscreenState)), retainedWebViews count before \(countBefore) and after \(self.retainedWebViews.count)")
	}
}
