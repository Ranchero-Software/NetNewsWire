//
//  PreloadedWebView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/25/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

final class PreloadedWebView: WKWebView {

	private var isReady: Bool = false
	private var readyCompletion: (() -> Void)?
	private var fullscreenStateObservation: NSKeyValueObservation?

	init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
		let configuration = WebViewConfiguration.configuration(with: articleIconSchemeHandler)
		super.init(frame: .zero, configuration: configuration)
		fullscreenStateObservation = observe(\.fullscreenState, options: []) { [weak self] _, _ in
			Task { @MainActor in
				guard let self else {
					return
				}
				WebViewFullscreenKeeper.shared.updateRetention(for: self)
			}
		}
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

	}

	func preload() {
		navigationDelegate = self
		loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
	}

	func ready(completion: @escaping () -> Void) {
		if isReady {
			completeRequest(completion: completion)
		} else {
			readyCompletion = completion
		}
	}
}

// MARK: WKScriptMessageHandler

extension PreloadedWebView: WKNavigationDelegate {

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		isReady = true
		if let completion = readyCompletion {
			completeRequest(completion: completion)
			readyCompletion = nil
		}
	}
}

// MARK: Private

private extension PreloadedWebView {

	func completeRequest(completion: @escaping () -> Void) {
		isReady = false
		navigationDelegate = nil
		completion()
	}
}
