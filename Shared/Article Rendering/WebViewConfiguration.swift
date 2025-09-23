//
//  WebViewConfiguration.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 1/15/25.
//  Copyright © 2025 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

final class WebViewConfiguration {

	static func configuration(with urlSchemeHandler: WKURLSchemeHandler) -> WKWebViewConfiguration {
		let configuration = WKWebViewConfiguration()

		configuration.preferences = preferences
		configuration.defaultWebpagePreferences = webpagePreferences
		configuration.mediaTypesRequiringUserActionForPlayback = .all
		configuration.setURLSchemeHandler(urlSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		configuration.userContentController = userContentController

#if os(iOS)
		configuration.allowsInlineMediaPlayback = true
#endif

		return configuration
	}
}

private extension WebViewConfiguration {

	static var preferences: WKPreferences {
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.minimumFontSize = 12

#if os(iOS)
		preferences.isElementFullscreenEnabled = true
#endif

		return preferences
	}

	static var webpagePreferences: WKWebpagePreferences {
		let preferences = WKWebpagePreferences()
		preferences.allowsContentJavaScript = AppDefaults.shared.isArticleContentJavascriptEnabled
		return preferences
	}

	static var userContentController: WKUserContentController {
		let userContentController = WKUserContentController()
		for script in articleScripts {
			userContentController.addUserScript(script)
		}
		return userContentController
	}

	static let articleScripts: [WKUserScript] = {
#if os(iOS)
		let filenames = ["main", "main_ios", "newsfoot"]
#else
		let filenames = ["main", "main_mac", "newsfoot"]
#endif

		let scripts = filenames.map { filename in
			let scriptURL = Bundle.main.url(forResource: filename, withExtension: ".js")!
			let scriptSource = try! String(contentsOf: scriptURL, encoding: .utf8)
			return WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
		}
		return scripts
	}()
}
