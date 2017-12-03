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

class DetailViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {

	var webview: WKWebView!
	
	var article: Article? {
		didSet {
			reloadHTML()
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

		let boxView = self.view as! DetailBox
		boxView.contentView = webview
		boxView.rs_addFullSizeConstraints(forSubview: webview)
		
		boxView.viewController = self
	}

	// MARK: Notifications

	@objc func timelineSelectionDidChange(_ note: Notification) {

		let timelineView = note.appInfo?.view
		if timelineView?.window === self.view.window {
			article = note.appInfo?.article
		}
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

		let appInfo = AppInfo()
		appInfo.view = self.view
		appInfo.url = link

		NotificationCenter.default.post(name: .MouseDidEnterLink, object: self, userInfo: appInfo.userInfo)
	}

	private func mouseDidExit(_ link: String) {

		let appInfo = AppInfo()
		appInfo.view = self.view
		appInfo.url = link

		NotificationCenter.default.post(name: .MouseDidExitLink, object: self, userInfo: appInfo.userInfo)
	}
}

class DetailBox: NSBox {
	
	weak var viewController: DetailViewController?
	
	override func viewWillStartLiveResize() {
		
		viewController?.viewWillStartLiveResize()
	}
	
	override func viewDidEndLiveResize() {
		
		viewController?.viewDidEndLiveResize()
	}
}
