//
//  DetailViewController.swift
//  Evergreen
//
//  Created by Brent Simmons on 7/26/15.
//  Copyright © 2015 Ranchero Software, LLC. All rights reserved.
//

import Foundation
import WebKit
import RSCore
import Data
import RSWeb

final class DetailViewController: NSViewController, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!
	@IBOutlet var noSelectionView: NoSelectionView!

	var webview: DetailWebView!

	var articles: [Article]? {
		didSet {
			if let articles = articles, articles.count == 1 {
				article = articles.first!
				return
			}
			article = nil
			if let _ = articles {
				noSelectionView.showMultipleSelection()
			}
			else {
				noSelectionView.showNoSelection()
			}
		}
	}
	
	private var article: Article? {
		didSet {
			reloadHTML()
			showOrHideWebView()
		}
	}

	private var webviewIsHidden: Bool {
		return containerView.contentView !== webview
	}

	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
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

		containerView.viewController = self

		showOrHideWebView()
	}

	// MARK: - Scrolling

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

	// MARK: - Notifications

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

// MARK: - WKNavigationDelegate

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

// MARK: - WKScriptMessageHandler

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

		if link.isEmpty {
			return
		}

		var userInfo = UserInfoDictionary()
		userInfo[UserInfoKey.view] = view
		userInfo[UserInfoKey.url] = link

		NotificationCenter.default.post(name: .MouseDidEnterLink, object: self, userInfo: userInfo)
	}

	private func mouseDidExit(_ link: String) {

		var userInfo = UserInfoDictionary()
		userInfo[UserInfoKey.view] = view
		userInfo[UserInfoKey.url] = link

		NotificationCenter.default.post(name: .MouseDidExitLink, object: self, userInfo: userInfo)
	}
}

// MARK: - Private

private extension DetailViewController {

	func reloadHTML() {

		if let article = article {
			let articleRenderer = ArticleRenderer(article: article, style: ArticleStylesManager.shared.currentStyle)
			webview.loadHTMLString(articleRenderer.html, baseURL: articleRenderer.baseURL)
		}
		else {
			webview.loadHTMLString("", baseURL: nil)
		}
	}

	func showOrHideWebView() {

		if let _ = article {
			switchToView(webview)
		}
		else {
			switchToView(noSelectionView)
		}
	}

	func switchToView(_ view: NSView) {

		if containerView.contentView == view {
			return
		}
		containerView.contentView = view
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

// MARK: -

final class DetailContainerView: NSView {

	@IBOutlet var detailStatusBarView: DetailStatusBarView!
	
	weak var viewController: DetailViewController? = nil

	private var didConfigureLayer = false

	override var wantsUpdateLayer: Bool {
		return true
	}

	var contentView: NSView? {
		didSet {
			if let oldContentView = oldValue {
				oldContentView.removeFromSuperviewWithoutNeedingDisplay()
			}
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

	override func updateLayer() {

		guard !didConfigureLayer else {
			return
		}
		if let layer = layer {
			let color = appDelegate.currentTheme.color(forKey: "MainWindow.Detail.backgroundColor")
			layer.backgroundColor = color.cgColor
			didConfigureLayer = true
		}
	}
}

// MARK: -

final class NoSelectionView: NSView {

	@IBOutlet var noSelectionLabel: NSTextField!
	@IBOutlet var multipleSelectionLabel: NSTextField!

	func showMultipleSelection() {

		noSelectionLabel.isHidden = true
		multipleSelectionLabel.isHidden = false
	}

	func showNoSelection() {

		noSelectionLabel.isHidden = false
		multipleSelectionLabel.isHidden = true
	}
}

// MARK: -

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
