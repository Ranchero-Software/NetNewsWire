//
//  DetailViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit
import RSCore
import Articles
import RSWeb

final class DetailViewController: NSViewController, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!
	@IBOutlet var statusBarView: DetailStatusBarView!
	
	var webview: DetailWebView!

	var articles: [Article]? {
		didSet {
			if articles == oldValue {
				return
			}
			statusBarView.mouseoverLink = nil
			reloadHTML()
		}
	}

	private var article: Article? {
		return articles?.first
	}

	private var webviewIsHidden: Bool {
		return containerView.contentView !== webview
	}

	override func viewDidLoad() {
		NotificationCenter.default.addObserver(self, selector: #selector(timelineSelectionDidChange(_:)), name: .TimelineSelectionDidChange, object: nil)
		
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
		
		webview = DetailWebView(frame: self.view.bounds, configuration: configuration)
		webview.uiDelegate = self
		webview.navigationDelegate = self
		webview.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webview.customUserAgent = userAgent
		}

		reloadHTML()
		containerView.contentView = webview
		containerView.viewController = self
	}

	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
	}

	// MARK: Scrolling

	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		if webviewIsHidden {
			callback(false)
			return
		}

		fetchScrollInfo { (scrollInfo) in
			callback(scrollInfo?.canScrollDown ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {

		guard !webviewIsHidden else {
			return
		}
		webview.scrollPageDown(sender)
	}

	// MARK: Notifications

	@objc func timelineSelectionDidChange(_ notification: Notification) {

		guard let userInfo = notification.userInfo else {
			return
		}
		guard let timelineView = userInfo[UserInfoKey.view] as? NSView, timelineView.window === view.window else {
			return
		}
		
		let timelineArticles = userInfo[UserInfoKey.articles] as? ArticleArray
		articles = timelineArticles
	}

	func viewWillStartLiveResize() {
		
		webview.evaluateJavaScript("document.body.style.overflow = 'hidden';", completionHandler: nil)
	}
	
	func viewDidEndLiveResize() {
		
		webview.evaluateJavaScript("document.body.style.overflow = 'visible';", completionHandler: nil)
	}
}

// MARK: WKNavigationDelegate

extension DetailViewController: WKNavigationDelegate {

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

// MARK: WKScriptMessageHandler

extension DetailViewController: WKScriptMessageHandler {

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
		statusBarView.mouseoverLink = link
	}

	private func mouseDidExit(_ link: String) {
		statusBarView.mouseoverLink = nil
	}
}

// MARK: Private

private extension DetailViewController {

	func reloadHTML() {
		let html: String
		let style = ArticleStylesManager.shared.currentStyle
		let appearance = self.view.effectiveAppearance
		var baseURL: URL? = nil

		if let articles = articles, articles.count > 1 {
			html = ArticleRenderer.multipleSelectionHTML(style: style, appearance: appearance)
		}
		else if let article = article {
			html = ArticleRenderer.articleHTML(article: article, style: style, appearance: appearance)
			baseURL = ArticleRenderer.baseURL(for: article)
		}
		else {
			html = ArticleRenderer.noSelectionHTML(style: style, appearance: appearance)
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

// MARK: - DetailContainerView

final class DetailContainerView: NSView {

	@IBOutlet var detailStatusBarView: DetailStatusBarView!
	
	weak var viewController: DetailViewController? = nil

	var contentView: NSView? {
		didSet {
			if contentView == oldValue {
				return
			}
			oldValue?.removeFromSuperviewWithoutNeedingDisplay()
			if let contentView = contentView {
				contentView.translatesAutoresizingMaskIntoConstraints = false
				addSubview(contentView, positioned: .below, relativeTo: detailStatusBarView)
				rs_addFullSizeConstraints(forSubview: contentView)
			}
		}
	}

	override func viewWillStartLiveResize() {
		viewController?.viewWillStartLiveResize()
	}
	
	override func viewDidEndLiveResize() {
		viewController?.viewDidEndLiveResize()
	}

	override func draw(_ dirtyRect: NSRect) {
		NSColor.textBackgroundColor.setFill()
		dirtyRect.fill()
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
