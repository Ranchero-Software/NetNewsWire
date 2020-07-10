//
//  PreloadedWebView.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import WebKit

class PreloadedWebView: WKWebView {
	
	private var isReady: Bool = false
	private var readyCompletion: ((PreloadedWebView) -> Void)?
	
	init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false
		
		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences
		configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
		#if os(iOS)
		configuration.allowsInlineMediaPlayback = true
		#endif
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		configuration.setURLSchemeHandler(articleIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		
		super.init(frame: .zero, configuration: configuration)
	}
	
	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
	
	func preload() {
		navigationDelegate = self
		loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
	}
	
	func ready(completion: @escaping (PreloadedWebView) -> Void) {
		if isReady {
			completeRequest(completion: completion)
		} else {
			readyCompletion = completion
		}
	}
	
	#if os(macOS)
	override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
		// There’s no API for affecting a WKWebView’s contextual menu.
		// (WebView had API for this.)
		//
		// This a minor hack. It hides unwanted menu items.
		// The menu item identifiers are not documented anywhere;
		// they could change, and this code would need updating.
		for menuItem in menu.items {
			if shouldHideMenuItem(menuItem) {
				menuItem.isHidden = true
			}
		}

		super.willOpenMenu(menu, with: event)
	}
	#endif
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
	
	func completeRequest(completion: @escaping (PreloadedWebView) -> Void) {
		isReady = false
		navigationDelegate = nil
		completion(self)
	}
	
}

#if os(macOS)
private extension NSUserInterfaceItemIdentifier {

	static let DetailMenuItemIdentifierReload = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierReload")
	static let DetailMenuItemIdentifierOpenLink = NSUserInterfaceItemIdentifier(rawValue: "WKMenuItemIdentifierOpenLink")
}

private extension PreloadedWebView {

	static let menuItemIdentifiersToHide: [NSUserInterfaceItemIdentifier] = [.DetailMenuItemIdentifierReload, .DetailMenuItemIdentifierOpenLink]
	static let menuItemIdentifierMatchStrings = ["newwindow", "download"]

	func shouldHideMenuItem(_ menuItem: NSMenuItem) -> Bool {

		guard let identifier = menuItem.identifier else {
			return false
		}

		if PreloadedWebView.menuItemIdentifiersToHide.contains(identifier) {
			return true
		}

		let lowerIdentifier = identifier.rawValue.lowercased()
		for matchString in PreloadedWebView.menuItemIdentifierMatchStrings {
			if lowerIdentifier.contains(matchString) {
				return true
			}
		}

		return false
	}
}
#endif
