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

class DetailViewController: NSViewController, WKNavigationDelegate, WKUIDelegate {
	
	var webview: WKWebView!
	
	var article: Article? {
		didSet {
			reloadHTML()
		}
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

		webview = WKWebView(frame: self.view.bounds, configuration: configuration)
		webview.uiDelegate = self
		webview.navigationDelegate = self
		webview.translatesAutoresizingMaskIntoConstraints = false
		let boxView = self.view as! DetailBox
		boxView.contentView = webview
		boxView.rs_addFullSizeConstraints(forSubview: webview)
		
		boxView.viewController = self
	}

	// MARK: Notifications

	func timelineSelectionDidChange(_ note: Notification) {

		let timelineView = note.userInfo?[viewKey] as! NSView

		if timelineView.window! === self.view.window {
			article = note.userInfo?[articleKey] as? Article
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
			let articleRenderer = ArticleRenderer(article: article, style: ArticleStylesManager.sharedInstance.currentStyle)
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
				openInBrowser(url.absoluteString)
			}
			
			decisionHandler(.cancel)
			return
		}
		
		decisionHandler(.allow)
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
