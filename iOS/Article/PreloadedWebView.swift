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
	
	private var isReady: Bool = false
	private var readyCompletion: (() -> Void)?

	static let userScripts: [WKUserScript] = {
		var scripts = [WKUserScript]()
		for fileName in ["main.js", "main_ios.js", "newsfoot.js"] {
			let scriptSource = try! String(contentsOf: baseURL.appending(path: fileName, directoryHint: .notDirectory))
			let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true, in: appScriptsWorld)
			scripts.append(script)
		}
		return scripts
	}()

	init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.javaScriptEnabled = true

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences
		configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
		configuration.allowsInlineMediaPlayback = true
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		configuration.setURLSchemeHandler(articleIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		
		let userContentController = WKUserContentController()
		let appScriptsWorld = WKContentWorld.world(name: "NetNewsWire")
		for script in Self.userScripts {
			userContentController.addUserScript(script)
		}
		configuration.userContentController = userContentController

		super.init(frame: .zero, configuration: configuration)
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
