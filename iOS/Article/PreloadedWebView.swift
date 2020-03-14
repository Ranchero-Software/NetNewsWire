//
//  PreloadedWebView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/25/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

class PreloadedWebView: WKWebView {
	
	private struct MessageName {
		static let domContentLoaded = "domContentLoaded"
	}
	
	private var isReady: Bool = false
	private var readyCompletion: ((PreloadedWebView) -> Void)?
	
	init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.javaScriptEnabled = true

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences
		configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
		configuration.allowsInlineMediaPlayback = true
		configuration.mediaTypesRequiringUserActionForPlayback = .video
		configuration.setURLSchemeHandler(articleIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		
		super.init(frame: .zero, configuration: configuration)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	func preload() {
		configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.domContentLoaded)
		loadFileURL(ArticleRenderer.page.url, allowingReadAccessTo: ArticleRenderer.page.baseURL)
	}
	
	func ready(completion: @escaping (PreloadedWebView) -> Void) {
		if isReady {
			completeRequest(completion: completion)
		} else {
			readyCompletion = completion
		}
	}
	
}

// MARK: WKScriptMessageHandler

extension PreloadedWebView: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if message.name == MessageName.domContentLoaded {
			isReady = true
			if let completion = readyCompletion {
				completeRequest(completion: completion)
				readyCompletion = nil
			}
		}
	}
	
}

// MARK: Private

private extension PreloadedWebView {
	
	func completeRequest(completion: @escaping (PreloadedWebView) -> Void) {
		isReady = false
		configuration.userContentController.removeScriptMessageHandler(forName: MessageName.domContentLoaded)
		completion(self)
	}
	
}
