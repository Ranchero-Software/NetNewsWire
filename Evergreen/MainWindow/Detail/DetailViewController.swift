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

final class DetailViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {

	@IBOutlet var containerView: DetailContainerView!

	var webview: WKWebView!
	var noSelectionView: NoSelectionView!

	var article: Article? {
		didSet {
			reloadHTML()
			showOrHideWebView()
		}
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
		
		webview = WKWebView(frame: self.view.bounds, configuration: configuration)
		webview.uiDelegate = self
		webview.navigationDelegate = self
		webview.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webview.customUserAgent = userAgent
		}

		noSelectionView = NoSelectionView(frame: self.view.bounds)

		containerView.viewController = self

		showOrHideWebView()
	}

	// MARK: Notifications

	@objc func timelineSelectionDidChange(_ notification: Notification) {

		guard let userInfo = notification.userInfo else {
			return
		}
		guard let timelineView = userInfo[UserInfoKey.view] as? NSView, timelineView.window === view.window else {
			return
		}
		
		let timelineArticle = userInfo[UserInfoKey.article] as? Article
		article = timelineArticle
	}

	func viewWillStartLiveResize() {
		
		webview.evaluateJavaScript("document.body.style.overflow = 'hidden';", completionHandler: nil)
	}
	
	func viewDidEndLiveResize() {
		
		webview.evaluateJavaScript("document.body.style.overflow = 'visible';", completionHandler: nil)
	}
	
	// MARK: Private

	private func reloadHTML() {

		if let article = article {
			let articleRenderer = ArticleRenderer(article: article, style: ArticleStylesManager.shared.currentStyle)
			webview.loadHTMLString(articleRenderer.html, baseURL: articleRenderer.baseURL)
		}
		else {
			webview.loadHTMLString("", baseURL: nil)
		}
	}

	private func showOrHideWebView() {

		if let _ = article {
			switchToView(webview)
		}
		else {
			switchToView(noSelectionView)
		}
	}

	private func switchToView(_ view: NSView) {

		if containerView.contentView == view {
			return
		}
		containerView.contentView = view
	}

	// MARK: WKNavigationDelegate
	
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

final class DetailContainerView: NSView {

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
				addSubview(contentView)
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

final class NoSelectionView: NSView {

	private var didConfigureLayer = false

	override var wantsUpdateLayer: Bool {
		return true
	}

	override func updateLayer() {

		guard !didConfigureLayer else {
			return
		}
		if let layer = layer {
			let color = appDelegate.currentTheme.color(forKey: "MainWindow.Detail.noSelectionView.backgroundColor")
			layer.backgroundColor = color.cgColor
			didConfigureLayer = true
		}
	}
}

