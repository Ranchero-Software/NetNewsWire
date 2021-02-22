//
//  DetailWebViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import WebKit
import RSCore
import RSWeb
import Articles

protocol DetailWebViewControllerDelegate: AnyObject {
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
	
	var article: Article? {
		switch state {
		case .article(let article):
			return article
		case .extracted(let article, _):
			return article
		default:
			return nil
		}
	}
	
	private var articleTextSize = AppDefaults.shared.articleTextSize

	#if !MAC_APP_STORE
		private var webInspectorEnabled: Bool {
			get {
				return webView.configuration.preferences._developerExtrasEnabled
			}
			set {
				webView.configuration.preferences._developerExtrasEnabled = newValue
			}
		}
	#endif
	
	private let detailIconSchemeHandler = DetailIconSchemeHandler()
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
		box.isTransparent = true
		box.titlePosition = .noTitle
		box.contentViewMargins = .zero
		box.fillColor = NSColor(named: "webviewBackgroundColor")!

		view = box
		
		let preferences = WKPreferences()
		preferences.minimumFontSize = 12.0
		preferences.javaScriptCanOpenWindowsAutomatically = false
		preferences.javaScriptEnabled = true

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences
		configuration.setURLSchemeHandler(detailIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)

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

		#if !MAC_APP_STORE
			webInspectorEnabled = AppDefaults.shared.webInspectorEnabled
			NotificationCenter.default.addObserver(self, selector: #selector(webInspectorEnabledDidChange(_:)), name: .WebInspectorEnabledDidChange, object: nil)
		#endif

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)

		webView.loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
	}

	// MARK: Notifications
	
	@objc func webFeedIconDidBecomeAvailable(_ note: Notification) {
		reloadArticleImage()
	}

	@objc func avatarDidBecomeAvailable(_ note: Notification) {
		reloadArticleImage()
	}

	@objc func faviconDidBecomeAvailable(_ note: Notification) {
		reloadArticleImage()
	}
	
	@objc func userDefaultsDidChange(_ note: Notification) {
		if articleTextSize != AppDefaults.shared.articleTextSize {
			articleTextSize = AppDefaults.shared.articleTextSize
			webView.evaluateJavaScript("updateTextSize(\"\(articleTextSize.cssClass)\");")
		}
	}
	
	// MARK: Media Functions
	
	func stopMediaPlayback() {
		webView.evaluateJavaScript("stopMediaPlayback();")
	}
	
	// MARK: Scrolling

	func canScrollDown(_ completion: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			completion(scrollInfo?.canScrollDown ?? false)
		}
	}

	func canScrollUp(_ completion: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			completion(scrollInfo?.canScrollUp ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {
		webView.scrollPageDown(sender)
	}

	override func scrollPageUp(_ sender: Any?) {
		webView.scrollPageUp(sender)
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
				let flags = navigationAction.modifierFlags
				let invert = flags.contains(.shift) || flags.contains(.command)
				Browser.open(url.absoluteString, invertPreference: invert)
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
			reloadHTML()

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

	func reloadArticleImage() {
		guard let article = article else { return }
		
		var components = URLComponents()
		components.scheme = ArticleRenderer.imageIconScheme
		components.path = article.articleID
		
		if let imageSrc = components.string {
			webView?.evaluateJavaScript("reloadArticleImage(\"\(imageSrc)\")")
		}
	}

	func reloadHTML() {
		let style = ArticleStylesManager.shared.currentStyle
		let rendering: ArticleRenderer.Rendering

		switch state {
		case .noSelection:
			rendering = ArticleRenderer.noSelectionHTML(style: style)
		case .multipleSelection:
			rendering = ArticleRenderer.multipleSelectionHTML(style: style)
		case .loading:
			rendering = ArticleRenderer.loadingHTML(style: style)
		case .article(let article):
			detailIconSchemeHandler.currentArticle = article
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		case .extracted(let article, let extractedArticle):
			detailIconSchemeHandler.currentArticle = article
			rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style)
		}
		
		let substitutions = [
			"title": rendering.title,
			"baseURL": rendering.baseURL,
			"style": rendering.style,
			"body": rendering.html
		]
		
		let html = try! MacroProcessor.renderedText(withTemplate: ArticleRenderer.page.html, substitutions: substitutions)
		webView.loadHTMLString(html, baseURL: ArticleRenderer.page.baseURL)
	}

	func fetchScrollInfo(_ completion: @escaping (ScrollInfo?) -> Void) {
		var javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: document.body.scrollTop}; x"
		if #available(macOS 10.15, *) {
			javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.pageYOffset}; x"
		}

		webView.evaluateJavaScript(javascriptString) { (info, error) in
			guard let info = info as? [String: Any] else {
				completion(nil)
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				completion(nil)
				return
			}

			let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: self.webView.frame.height, offsetY: offsetY)
			completion(scrollInfo)
		}
	}

	#if !MAC_APP_STORE
		@objc func webInspectorEnabledDidChange(_ notification: Notification) {
			self.webInspectorEnabled = notification.object! as! Bool
		}
	#endif
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
