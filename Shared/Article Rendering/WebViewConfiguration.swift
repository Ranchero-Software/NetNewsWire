//
//  WebViewConfiguration.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/15/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import os
import WebKit

@MainActor final class WebViewConfiguration {

	private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "WebViewConfiguration")

	private static var contentBlockingRuleList: WKContentRuleList?
	private static var configuredContentControllers = NSHashTable<WKUserContentController>.weakObjects()

	static func configuration(with urlSchemeHandler: WKURLSchemeHandler) -> WKWebViewConfiguration {
		assert(Thread.isMainThread)

		let configuration = WKWebViewConfiguration()

		configuration.preferences = preferences
		configuration.defaultWebpagePreferences = webpagePreferences
		configuration.mediaTypesRequiringUserActionForPlayback = .all
		configuration.setURLSchemeHandler(urlSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		configuration.userContentController = userContentController

		// Present article content as NetNewsWire on top of WebKit's default browser UA, rather than a non-browser string.
		// <https://github.com/Ranchero-Software/NetNewsWire/issues/4453>
		configuration.applicationNameForUserAgent = "NetNewsWire"

#if os(iOS)
		configuration.allowsInlineMediaPlayback = true
#endif

		return configuration
	}

	/// Add content blocking rules to a web view. Call before loading article content.
	static func addContentBlockingRules(to webView: WKWebView) {
		guard let contentBlockingRuleList else {
			return
		}
		let contentController = webView.configuration.userContentController
		if !configuredContentControllers.contains(contentController) {
			contentController.add(contentBlockingRuleList)
			configuredContentControllers.add(contentController)
		}
	}

	/// Compile content blocking rules. Call early at app startup.
	static func compileContentBlockingRules() async {

		guard let url = Bundle.main.url(forResource: "ContentRules", withExtension: "json") else {
			logger.warning("WebViewConfiguration: ContentRules.json not found in bundle")
			return
		}

		let rulesJSON: String
		do {
			rulesJSON = try String(contentsOf: url, encoding: .utf8)
		} catch {
			logger.error("WebViewConfiguration: Failed to read ContentRules.json: \(error.localizedDescription)")
			return
		}

		let startTime = CFAbsoluteTimeGetCurrent()

		do {
			let ruleList = try await WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ContentBlockingRules", encodedContentRuleList: rulesJSON)
			let elapsed = CFAbsoluteTimeGetCurrent() - startTime
			if let ruleList {
				contentBlockingRuleList = ruleList
				logger.info("WebViewConfiguration: Compiled content blocking rules in \(elapsed, format: .fixed(precision: 4))s")
			}
		} catch {
			let elapsed = CFAbsoluteTimeGetCurrent() - startTime
			logger.error("WebViewConfiguration: Failed to compile content blocking rules in \(elapsed, format: .fixed(precision: 4))s: \(error.localizedDescription)")
		}
	}
}

private extension WebViewConfiguration {

	static var preferences: WKPreferences {
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.minimumFontSize = 12
		preferences.isElementFullscreenEnabled = true

		return preferences
	}

	static var webpagePreferences: WKWebpagePreferences {
		assert(Thread.isMainThread)

		let preferences = WKWebpagePreferences()
		preferences.allowsContentJavaScript = AppDefaults.shared.isArticleContentJavascriptEnabled
		return preferences
	}

	static var userContentController: WKUserContentController {
		let userContentController = WKUserContentController()
		for script in articleScripts {
			userContentController.addUserScript(script)
		}
		if let contentBlockingRuleList {
			userContentController.add(contentBlockingRuleList)
		}
		return userContentController
	}

	static let articleScripts: [WKUserScript] = {
#if os(iOS)
		let filenames = ["main", "main_ios", "newsfoot"]
#else
		let filenames = ["main", "main_mac", "newsfoot"]
#endif

		var scripts = filenames.map { filename in
			let scriptURL = Bundle.main.url(forResource: filename, withExtension: ".js")!
			let scriptSource = try! String(contentsOf: scriptURL, encoding: .utf8)
			return WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
		}

#if os(iOS)
		scripts.insert(feedInfoLabelScript, at: 0)
#endif
		return scripts
	}()

#if os(iOS)
	// main_ios.js uses nnwGetFeedInfoLabel as the feed icon's accessibility label.
	// The label is passed in from here because localized strings can't live in a static .js file.
	// JSON encoding escapes the translation so it's a valid JavaScript string literal.
	static let feedInfoLabelScript: WKUserScript = {
		let label = NSLocalizedString("Get Feed Info", comment: "Get Feed Info")
		let json = String(data: try! JSONSerialization.data(withJSONObject: label, options: .fragmentsAllowed), encoding: .utf8)!
		return WKUserScript(source: "const nnwGetFeedInfoLabel = \(json);", injectionTime: .atDocumentStart, forMainFrameOnly: true)
	}()
#endif
}
