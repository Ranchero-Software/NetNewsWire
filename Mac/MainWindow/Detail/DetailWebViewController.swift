//
//  DetailWebViewController.swift
//  NetNewsWire
//
//  Created by Brent Simmons on 2/11/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import AppKit
import WebKit
import Web
import Articles
import Core

protocol DetailWebViewControllerDelegate: AnyObject {
	
	@MainActor func mouseDidEnter(_: DetailWebViewController, link: String)
	@MainActor func mouseDidExit(_: DetailWebViewController)
}

final class DetailWebViewController: NSViewController {

	weak var delegate: DetailWebViewControllerDelegate?
	var webView: DetailWebView!
	var state: DetailState = .noSelection {
		didSet {
			if state != oldValue {
				switch state {
				case .article(_, let scrollY), .extracted(_, _, let scrollY):
					windowScrollY = scrollY
				default:
					break
				}
				reloadHTML()
			}
		}
	}
	
	var article: Article? {
		switch state {
		case .article(let article, _):
			return article
		case .extracted(let article, _, _):
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
	private var windowScrollY: CGFloat?

	private let appIsInApplicationsFolder: Bool = {
#if DEBUG
		return true // We want the same experience most people have. Search in this file for appIsInApplicationsFolder for more details.
#else
		let appPath = Bundle.main.bundlePath
		let applicationsFolderURL = try! FileManager.default.url(for: .applicationDirectory, in: .localDomainMask, appropriateFor: nil, create: false)
		let applicationsFolderPath = applicationsFolderURL.path
		return appPath.hasPrefix(applicationsFolderPath)
#endif
	}()

	private var isShowingExtractedArticle: Bool {
		switch state {
		case .extracted(_, _, _):
			return true
		default:
			return false
		}
	}

	static let userScripts: [WKUserScript] = {
		let filenames = ["main", "main_mac", "newsfoot"]
		let scripts = filenames.map { filename in
			let scriptURL = Bundle.main.url(forResource: filename, withExtension: ".js")!
			let scriptSource = try! String(contentsOf: scriptURL)
			return WKUserScript(source: scriptSource, injectionTime: .atDocumentStart, forMainFrameOnly: true)
		}
		return scripts
	}()

	private struct MessageName {
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
		static let windowDidScroll = "windowDidScroll"
	}

	override func loadView() {
		let preferences = WKPreferences()
		preferences.minimumFontSize = 12.0
		preferences.javaScriptCanOpenWindowsAutomatically = false

		let configuration = WKWebViewConfiguration()
		configuration.preferences = preferences
		configuration.defaultWebpagePreferences.allowsContentJavaScript = AppDefaults.shared.isArticleContentJavascriptEnabled
		configuration.setURLSchemeHandler(detailIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)
		configuration.mediaTypesRequiringUserActionForPlayback = .all

		let userContentController = WKUserContentController()
		userContentController.add(self, name: MessageName.windowDidScroll)
		userContentController.add(self, name: MessageName.mouseDidEnter)
		userContentController.add(self, name: MessageName.mouseDidExit)
		for script in Self.userScripts {
			userContentController.addUserScript(script)
		}
		configuration.userContentController = userContentController

		webView = DetailWebView(frame: NSRect.zero, configuration: configuration)
		webView.uiDelegate = self
		webView.navigationDelegate = self
		webView.keyboardDelegate = keyboardDelegate
		webView.translatesAutoresizingMaskIntoConstraints = false
		if let userAgent = UserAgent.fromInfoPlist() {
			webView.customUserAgent = userAgent
		}

		view = webView

		// Hide the web view until the first reload (navigation) is complete (plus some delay) to avoid the awful white flash that happens on the initial display in dark mode.
		// See bug #901.
		webView.isHidden = true
		waitingForFirstReload = true

		#if !MAC_APP_STORE
			webInspectorEnabled = AppDefaults.shared.webInspectorEnabled
			NotificationCenter.default.addObserver(self, selector: #selector(webInspectorEnabledDidChange(_:)), name: .WebInspectorEnabledDidChange, object: nil)
		#endif

		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(currentArticleThemeDidChangeNotification(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)

		webView.loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
	}

	// MARK: Notifications
	
	@objc func feedIconDidBecomeAvailable(_ note: Notification) {
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
		
			Task { @MainActor in
				await reloadHTMLMaintainingScrollPosition()
			}
		}
	}

	@objc func currentArticleThemeDidChangeNotification(_ note: Notification) {

		Task { @MainActor in
			await reloadHTMLMaintainingScrollPosition()
		}
	}
	
	// MARK: Media Functions
	
	func stopMediaPlayback() {
		webView.evaluateJavaScript("stopMediaPlayback();")
	}
	
	// MARK: Scrolling

	func canScrollDown() async -> Bool {
		let scrollInfo = await fetchScrollInfo()
		return scrollInfo?.canScrollDown ?? false
	}

	func canScrollUp() async -> Bool {
		let scrollInfo = await fetchScrollInfo()
		return scrollInfo?.canScrollUp ?? false
	}

	override func scrollPageDown(_ sender: Any?) {
		webView.scrollPageDown(sender)
	}

	override func scrollPageUp(_ sender: Any?) {
		webView.scrollPageUp(sender)
	}

	// MARK: State Restoration
	
	func saveState(to state: inout [AnyHashable : Any]) {
		state[UserInfoKey.isShowingExtractedArticle] = isShowingExtractedArticle
		state[UserInfoKey.articleWindowScrollY] = windowScrollY
	}
	
}

// MARK: - WKScriptMessageHandler

extension DetailWebViewController: WKScriptMessageHandler {

	nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

		if message.name == MessageName.windowDidScroll {

			let updatedWindowScrollY = message.body as? CGFloat
			Task { @MainActor in
				windowScrollY = updatedWindowScrollY
			}

		} else if message.name == MessageName.mouseDidEnter, let link = message.body as? String {

			Task { @MainActor in
				delegate?.mouseDidEnter(self, link: link)
			}

		} else if message.name == MessageName.mouseDidExit {

			Task { @MainActor in
				delegate?.mouseDidExit(self)
			}
		}
	}
}

// MARK: - WKNavigationDelegate & WKUIDelegate

extension DetailWebViewController: WKNavigationDelegate, WKUIDelegate {

	// Bottleneck through which WebView-based URL opens go
	func openInBrowser(_ url: URL, flags: NSEvent.ModifierFlags) {
		let invert = flags.contains(.shift) || flags.contains(.command)
		Browser.open(url.absoluteString, invertPreference: invert)
	}

	// WKNavigationDelegate

	nonisolated public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if navigationAction.navigationType == .linkActivated {
			if let url = navigationAction.request.url {
				let flags = navigationAction.modifierFlags
				Task { @MainActor in
					self.openInBrowser(url, flags: flags)
				}
			}
			decisionHandler(.cancel)
			return
		}

		decisionHandler(.allow)
	}
	
	nonisolated public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

		Task { @MainActor in
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
			} else {
				if let windowScrollY = windowScrollY {
					_ = try? await webView.evaluateJavaScript("window.scrollTo(0, \(windowScrollY));")
					self.windowScrollY = nil
				}
			}
		}
	}

	// WKUIDelegate
	
	nonisolated func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		// This method is reached when WebKit handles a JavaScript based window.open() invocation, for example. One
		// example where this is used is in YouTube's embedded video player when a user clicks on the video's title
		// or on the "Watch in YouTube" button. For our purposes we'll handle such window.open calls the same way we
		// handle clicks on a URL.
		if let url = navigationAction.request.url {
			let flags = navigationAction.modifierFlags

			Task { @MainActor in
				self.openInBrowser(url, flags: flags)
			}
		}

		return nil
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
	
	func reloadHTMLMaintainingScrollPosition() async {
		let scrollInfo = await fetchScrollInfo()
		windowScrollY = scrollInfo?.offsetY
		self.reloadHTML()
	}

	func reloadHTML() {
		delegate?.mouseDidExit(self)
		
		let theme = ArticleThemesManager.shared.currentTheme
		let rendering: ArticleRenderer.Rendering

		switch state {
		case .noSelection:
			rendering = ArticleRenderer.noSelectionHTML(theme: theme)
		case .multipleSelection:
			rendering = ArticleRenderer.multipleSelectionHTML(theme: theme)
		case .loading:
			rendering = ArticleRenderer.loadingHTML(theme: theme)
		case .article(let article, _):
			detailIconSchemeHandler.currentArticle = article
			rendering = ArticleRenderer.articleHTML(article: article, theme: theme)
		case .extracted(let article, let extractedArticle, _):
			detailIconSchemeHandler.currentArticle = article
			rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, theme: theme)
		}
		
		let substitutions = [
			"title": rendering.title,
			"baseURL": rendering.baseURL,
			"style": rendering.style,
			"body": rendering.html
		]
		
		let html = try! MacroProcessor.renderedText(withTemplate: ArticleRenderer.page.html, substitutions: substitutions)

		// When the app is in /Applications, we want the baseURL to be a local folder in the app bundle. This gives us best performance.
		//
		// When the app is *not* in /Applications — in ~/Applications, for instance — we don’t want the baseURL to be a local folder —
		// because we could up sending referers with a URL like file:///Users/harvey/Applications/NetNewsWire/Contents/Resources
		// and obviously we don’t want to send people’s names.
		// (A URL like file:///Applications/NetNewsWire/Contents/Resources is fine — obviously not exposing a name.)
		//
		// So, when outside of the /Applications folder, the baseURL is the permalink of the article.
		// Which is what we’d really want all the time, right? Except that we’ve had a report of a performance issue
		// when we do that all the time, so we prefer the local baseURL when we can.
		let localBaseURL = ArticleRenderer.page.baseURL
		let articleBaseURL = URL(string: rendering.baseURL)
		let baseURL = appIsInApplicationsFolder ? localBaseURL : articleBaseURL

		webView.loadHTMLString(html, baseURL: baseURL)
	}

	func fetchScrollInfo() async -> ScrollInfo? {

		let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.pageYOffset}; x"

		guard let info = try? await webView.evaluateJavaScript(javascriptString) else {
			return nil
		}
		guard let info = info as? [String: Any] else {
			return nil
		}
		guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
			return nil
		}

		let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: self.webView.frame.height, offsetY: offsetY)
		return scrollInfo
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
