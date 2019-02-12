//
//  DetailWebViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import WebKit
import RSWeb
import Articles

enum DetailWebViewState: Equatable {
	case noSelection
	case multipleSelection
	case article(Article)
}

final class DetailWebViewController: NSViewController, WKUIDelegate {

	var webview: DetailWebView!
	var state: DetailWebViewState = .noSelection {
		didSet {
			if state != oldValue {
				reloadHTML()
			}
		}
	}

	override func loadView() {
		let preferences = WKPreferences()
		preferences.minimumFontSize = 12.0
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.javaEnabled = false
		preferences.javaScriptEnabled = true
		preferences.plugInsEnabled = false

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences

		let userContentController = WKUserContentController()
		userContentController.add(self, name: MessageName.mouseDidEnter)
		userContentController.add(self, name: MessageName.mouseDidExit)
		configuration.userContentController = userContentController

		webview = DetailWebView(frame: NSRect.zero, configuration: configuration)
		webview.uiDelegate = self
		webview.navigationDelegate = self
		webview.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webview.customUserAgent = userAgent
		}
		webview.nextResponder = self
		view = webview
	}

	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
	}
}

// MARK: - WKScriptMessageHandler

extension DetailWebViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

		if message.name == MessageName.mouseDidEnter, let link = message.body as? String {
			mouseDidEnter(link)
		}
		else if message.name == MessageName.mouseDidExit, let link = message.body as? String{
			mouseDidExit(link)
		}
	}

	private func mouseDidEnter(_ link: String) {
		guard !link.isEmpty else {
			return
		}
//		statusBarView.mouseoverLink = link
	}

	private func mouseDidExit(_ link: String) {
//		statusBarView.mouseoverLink = nil
	}
}

// MARK: - WKNavigationDelegate

extension DetailWebViewController: WKNavigationDelegate {

	public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated {
			if let url = navigationAction.request.url {
				Browser.open(url.absoluteString)
			}
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}
}

// MARK: - Private

private extension DetailWebViewController {

	func reloadHTML() {
		let style = ArticleStylesManager.shared.currentStyle
		let appearance = self.view.effectiveAppearance
		let html: String
		var baseURL: URL? = nil

		switch state {
		case .noSelection:
			html = ArticleRenderer.noSelectionHTML(style: style, appearance: appearance)
		case .multipleSelection:
			html = ArticleRenderer.multipleSelectionHTML(style: style, appearance: appearance)
		case .article(let article):
			html = ArticleRenderer.articleHTML(article: article, style: style, appearance: appearance)
			baseURL = article.baseURL
		}

		webview.loadHTMLString(html, baseURL: baseURL)
	}
}

private extension Article {

	var baseURL: URL? {
		var s = url
		if s == nil {
			s = feed?.homePageURL
		}
		if s == nil {
			s = feed?.url
		}

		guard let urlString = s else {
			return nil
		}
		var urlComponents = URLComponents(string: urlString)
		if urlComponents == nil {
			return nil
		}

		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents!.fragment = nil
		guard let url = urlComponents!.url, url.scheme == "http" || url.scheme == "https" else {
			return nil
		}
		return url
	}
}
