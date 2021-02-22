//
//  WebViewController.swift
//  Multiplatform macOS
//
//  Created by Maurice Parker on 7/8/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import AppKit
import Combine
import RSCore
import Articles

protocol WebViewControllerDelegate: AnyObject {
	func webViewController(_: WebViewController, articleExtractorButtonStateDidUpdate: ArticleExtractorButtonState)
}

class WebViewController: NSViewController {
	
	private struct MessageName {
		static let imageWasClicked = "imageWasClicked"
		static let imageWasShown = "imageWasShown"
		static let mouseDidEnter = "mouseDidEnter"
		static let mouseDidExit = "mouseDidExit"
		static let showFeedInspector = "showFeedInspector"
	}
	
	var statusBarView: WebStatusBarView!
	
	private var webView: PreloadedWebView?
	
	private var articleExtractor: ArticleExtractor? = nil
	var extractedArticle: ExtractedArticle?
	var isShowingExtractedArticle = false

	var articleExtractorButtonState: ArticleExtractorButtonState = .off {
		didSet {
			delegate?.webViewController(self, articleExtractorButtonStateDidUpdate: articleExtractorButtonState)
		}
	}
	
	var sceneModel: SceneModel?
	weak var delegate: WebViewControllerDelegate?
	
	var articles: [Article]? {
		didSet {
			if oldValue != articles {
				loadWebView()
			}
		}
	}
	
	private var cancellables = Set<AnyCancellable>()

	override func loadView() {
		view = NSView()
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		
		statusBarView = WebStatusBarView()
		statusBarView.translatesAutoresizingMaskIntoConstraints = false
		self.view.addSubview(statusBarView)
		NSLayoutConstraint.activate([
			self.view.leadingAnchor.constraint(equalTo: statusBarView.leadingAnchor, constant: -6),
			self.view.trailingAnchor.constraint(greaterThanOrEqualTo: statusBarView.trailingAnchor, constant: 6),
			self.view.bottomAnchor.constraint(equalTo: statusBarView.bottomAnchor, constant: 2),
			statusBarView.heightAnchor.constraint(equalToConstant: 20)
		])

		sceneModel?.timelineModel.selectedArticlesPublisher?.sink { [weak self] articles in
			self?.articles = articles
		}
		.store(in: &cancellables)
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

	// MARK: API
	
	func focus() {
		webView?.becomeFirstResponder()
	}

	func canScrollDown(_ completion: @escaping (Bool) -> Void) {
		fetchScrollInfo { (scrollInfo) in
			completion(scrollInfo?.canScrollDown ?? false)
		}
	}

	override func scrollPageDown(_ sender: Any?) {
		webView?.scrollPageDown(sender)
	}
	
	func toggleArticleExtractor() {

		guard let article = articles?.first else {
			return
		}

		guard articleExtractor?.state != .processing else {
			stopArticleExtractor()
			loadWebView()
			return
		}

		guard !isShowingExtractedArticle else {
			isShowingExtractedArticle = false
			loadWebView()
			articleExtractorButtonState = .off
			return
		}

		if let articleExtractor = articleExtractor {
			if article.preferredLink == articleExtractor.articleLink {
				isShowingExtractedArticle = true
				loadWebView()
				articleExtractorButtonState = .on
			}
		} else {
			startArticleExtractor()
		}

	}
	
	func stopArticleExtractorIfProcessing() {
		if articleExtractor?.state == .processing {
			stopArticleExtractor()
		}
	}

	func stopWebViewActivity() {
		if let webView = webView {
			stopMediaPlayback(webView)
		}
	}

}

// MARK: ArticleExtractorDelegate

extension WebViewController: ArticleExtractorDelegate {

	func articleExtractionDidFail(with: Error) {
		stopArticleExtractor()
		articleExtractorButtonState = .error
		loadWebView()
	}

	func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
		if articleExtractor?.state != .cancelled {
			self.extractedArticle = extractedArticle
			isShowingExtractedArticle = true
			loadWebView()
			articleExtractorButtonState = .on
		}
	}

}


// MARK: WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		switch message.name {
		case MessageName.imageWasShown:
			return
		case MessageName.imageWasClicked:
			return
		case MessageName.mouseDidEnter:
			if let link = message.body as? String {
				statusBarView.mouseoverLink = link
			}
		case MessageName.mouseDidExit:
			statusBarView.mouseoverLink = nil
		case MessageName.showFeedInspector:
			return
		default:
			return
		}
	}
	
}

extension WebViewController: WKNavigationDelegate {

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
	
}

// MARK: Private

private extension WebViewController {

	func loadWebView() {
		if let webView = webView {
			self.renderPage(webView)
			return
		}
		
		sceneModel?.webViewProvider?.dequeueWebView() { webView in
			
			webView.ready {
				
				// Add the webview
				self.webView = webView
				
				webView.translatesAutoresizingMaskIntoConstraints = false
				self.view.addSubview(webView, positioned: .below, relativeTo: self.statusBarView)
				NSLayoutConstraint.activate([
					self.view.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
					self.view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
					self.view.topAnchor.constraint(equalTo: webView.topAnchor),
					self.view.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
				])
				
				webView.navigationDelegate = self
			
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.mouseDidEnter)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.mouseDidExit)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.showFeedInspector)

				self.renderPage(webView)
			
			}
		}
		
	}

	func renderPage(_ webView: PreloadedWebView) {
		let style = ArticleStylesManager.shared.currentStyle
		let rendering: ArticleRenderer.Rendering

		if articles?.count ?? 0 > 1 {
			rendering = ArticleRenderer.multipleSelectionHTML(style: style)
		} else if let articleExtractor = articleExtractor, articleExtractor.state == .processing {
			rendering = ArticleRenderer.loadingHTML(style: style)
		} else if let articleExtractor = articleExtractor, articleExtractor.state == .failedToParse, let article = articles?.first {
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		} else if let article = articles?.first, let extractedArticle = extractedArticle {
			if isShowingExtractedArticle {
				rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style)
			} else {
				rendering = ArticleRenderer.articleHTML(article: article, style: style)
			}
		} else if let article = articles?.first {
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		} else {
			rendering = ArticleRenderer.noSelectionHTML(style: style)
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
		guard let webView = webView else {
			completion(nil)
			return
		}
		
		let javascriptString = "var x = {contentHeight: document.body.scrollHeight, offsetY: window.pageYOffset}; x"

		webView.evaluateJavaScript(javascriptString) { (info, error) in
			guard let info = info as? [String: Any] else {
				completion(nil)
				return
			}
			guard let contentHeight = info["contentHeight"] as? CGFloat, let offsetY = info["offsetY"] as? CGFloat else {
				completion(nil)
				return
			}

			let scrollInfo = ScrollInfo(contentHeight: contentHeight, viewHeight: webView.frame.height, offsetY: offsetY)
			completion(scrollInfo)
		}
	}
	
	func startArticleExtractor() {
		if let link = articles?.first?.preferredLink, let extractor = ArticleExtractor(link) {
			extractor.delegate = self
			extractor.process()
			articleExtractor = extractor
			articleExtractorButtonState = .animated
		}
	}

	func stopArticleExtractor() {
		articleExtractor?.cancel()
		articleExtractor = nil
		isShowingExtractedArticle = false
		articleExtractorButtonState = .off
	}

	func reloadArticleImage() {
		guard let article = articles?.first else { return }

		var components = URLComponents()
		components.scheme = ArticleRenderer.imageIconScheme
		components.path = article.articleID
		
		if let imageSrc = components.string {
			webView?.evaluateJavaScript("reloadArticleImage(\"\(imageSrc)\")")
		}
	}
	
	func stopMediaPlayback(_ webView: WKWebView) {
		webView.evaluateJavaScript("stopMediaPlayback();")
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
