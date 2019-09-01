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
	var webView: DetailWebView!
	var state: DetailState = .noSelection {
		didSet {
			if state != oldValue {
				reloadHTML()
			}
		}
	}
	
	private var waitingForFirstReload = false
	private let keyboardDelegate = DetailKeyboardDelegate()
	
	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
	}

	override func loadView() {
		// Wrap the webview in a box configured with the same background color that the web view uses
		let box = NSBox(frame: .zero)
		box.boxType = .custom
		box.borderType = .noBorder
		box.titlePosition = .noTitle
		box.contentViewMargins = .zero
		box.fillColor = NSColor(named: "webviewBackgroundColor")!

		view = box
		
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

		webView = DetailWebView(frame: NSRect.zero, configuration: configuration)
		webView.uiDelegate = self
		webView.navigationDelegate = self
		webView.keyboardDelegate = keyboardDelegate
		webView.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webView.customUserAgent = userAgent
		}

		box.addSubview(webView)

		let constraints = [
			webView.topAnchor.constraint(equalTo: view.topAnchor),
			webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
			webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
		]

		NSLayoutConstraint.activate(constraints)

		// Hide the web view until the first reload (navigation) is complete (plus some delay) to avoid the awful white flash that happens on the initial display in dark mode.
		// See bug #901.
		webView.isHidden = true
		waitingForFirstReload = true

		reloadHTML()
	}

	// MARK: Scrolling

	func canScrollDown(_ callback: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			callback(scrollInfo?.canScrollDown ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {
		webView.scrollPageDown(sender)
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
	
	public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// See note in viewDidLoad()
		if waitingForFirstReload {
			assert(webView.isHidden)
			waitingForFirstReload = false

			// Waiting for the first navigation to complete isn't long enough to avoid the flash of white.
			// A hard coded value is awful, but 5/100th of a second seems to be enough.
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
				webView.isHidden = false
			}
		}
	}
}

// MARK: - Private

private extension DetailWebViewController {

	func reloadHTML() {
		let style = ArticleStylesManager.shared.currentStyle
		let html: String

		switch state {
		case .noSelection:
			html = ArticleRenderer.noSelectionHTML(style: style)
		case .multipleSelection:
			html = ArticleRenderer.multipleSelectionHTML(style: style)
		case .article(let article):
			html = ArticleRenderer.articleHTML(article: article, style: style)
		}

		webView.loadHTMLString(html, baseURL: nil)
	}

	func fetchScrollInfo(_ callback: @escaping (ScrollInfo?) -> Void) {
		let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"

		webView.evaluateJavaScript(javascriptString) { (info, error) in
			guard let info = info as? [String: Any] else {
				callback(nil)
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				callback(nil)
				return
			}

			let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: self.webView.frame.height, offsetY: offsetY)
			callback(scrollInfo)
		}
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
