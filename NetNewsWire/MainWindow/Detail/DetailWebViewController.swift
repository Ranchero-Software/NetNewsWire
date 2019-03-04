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

protocol DetailWebViewControllerDelegate: class {
	func mouseDidEnter(_: DetailWebViewController, link: String)
	func mouseDidExit(_: DetailWebViewController, link: String)
}

final class DetailWebViewController: NSViewController, WKUIDelegate {

	weak var delegate: DetailWebViewControllerDelegate?
	var webview: DetailWebView!
	var state: DetailState = .noSelection {
		didSet {
			if state != oldValue {
				reloadHTML()
			}
		}
	}
	
	private let keyboardDelegate = DetailKeyboardDelegate()
	
	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
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
		webview.keyboardDelegate = keyboardDelegate
		webview.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webview.customUserAgent = userAgent
		}

		view = webview

		DispatchQueue.main.async {
			// Must do this async, because reloadHTML references view.effectiveAppearance,
			// which causes loadView to get called. Infinite loop.
			self.reloadHTML()
		}
	}

	// MARK: Scrolling

	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			callback(scrollInfo?.canScrollDown ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {
		webview.scrollPageDown(sender)
	}
}

// MARK: - WKScriptMessageHandler

extension DetailWebViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if message.name == MessageName.mouseDidEnter, let link = message.body as? String {
			delegate?.mouseDidEnter(self, link: link)
		}
		else if message.name == MessageName.mouseDidExit, let link = message.body as? String{
			delegate?.mouseDidExit(self, link: link)
		}
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
		let appearance = view.effectiveAppearance
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

	func fetchScrollInfo(_ callback: @escaping (ScrollInfo?) -> Void) {
		let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"

		webview.evaluateJavaScript(javascriptString) { (info, error) in
			guard let info = info as? [String: Any] else {
				callback(nil)
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				callback(nil)
				return
			}

			let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: self.webview.frame.height, offsetY: offsetY)
			callback(scrollInfo)
		}
	}
}

// MARK: - Article extension

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


// MARK: - ScrollInfo

private struct ScrollInfo {

	let contentHeight: CGFloat
	let viewHeight: CGFloat
	let offsetY: CGFloat
	let canScrollDown: Bool
	let canScrollUp: Bool

	init(contentHeight: CGFloat, viewHeight: CGFloat, offsetY: CGFloat) {
		self.contentHeight = contentHeight
		self.viewHeight = viewHeight
		self.offsetY = offsetY

		self.canScrollDown = viewHeight + offsetY < contentHeight
		self.canScrollUp = offsetY > 0.1
	}
}
