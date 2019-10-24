//
//  ArticleViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import SafariServices

enum ArticleViewState: Equatable {
	case noSelection
	case multipleSelection
	case loading
	case article(Article)
	case extracted(Article, ExtractedArticle)
}

class ArticleViewController: UIViewController {
	
	private struct MessageName {
		static let imageWasClicked = "imageWasClicked"
		static let imageWasShown = "imageWasShown"
	}

	@IBOutlet private weak var nextUnreadBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var prevArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var nextArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var actionBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var browserBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var webViewContainer: UIView!

	private var articleExtractorButton: ArticleExtractorButton = {
		let button = ArticleExtractorButton(type: .system)
		button.frame = CGRect(x: 0, y: 0, width: 44.0, height: 44.0)
		button.setImage(AppAssets.articleExtractorOff, for: .normal)
		return button
	}()
	
	private var webView: WKWebView!
	private lazy var transition = ImageTransition(controller: self)
	private var clickedImageCompletion: (() -> Void)?

	weak var coordinator: SceneCoordinator!
	
	var state: ArticleViewState = .noSelection {
		didSet {
			if state != oldValue {
				updateUI()
				reloadHTML()
			}
		}
	}
	
	var currentArticle: Article? {
		switch state {
		case .article(let article):
			return article
		case .extracted(let article, _):
			return article
		default:
			return nil
		}
	}
	
	var articleExtractorButtonState: ArticleExtractorButtonState {
		get {
			return articleExtractorButton.buttonState
		}
		set {
			articleExtractorButton.buttonState = newValue
		}
	}
	
	private let keyboardManager = KeyboardManager(type: .detail)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	deinit {
		if webView != nil  {
			webView.removeFromSuperview()
			ArticleViewControllerWebViewProvider.shared.enqueueWebView(webView)
			webView = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		articleExtractorButton.addTarget(self, action: #selector(toggleArticleExtractor(_:)), for: .touchUpInside)
		navigationItem.titleView = articleExtractorButton

		ArticleViewControllerWebViewProvider.shared.dequeueWebView() { webView in
			
			self.webView = webView
			self.webViewContainer.addChildAndPin(webView)
			webView.navigationDelegate = self
			webView.uiDelegate = self

			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasClicked)
			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasShown)
			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)

			// Even though page.html should be loaded into this webview, we have to do it again
			// to work around this bug: http://www.openradar.me/22855188
			let url = Bundle.main.url(forResource: "page", withExtension: "html")!
			webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
//			let request = URLRequest(url: url)
//			webView.load(request)

		}
		
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateProgressIndicatorIfNeeded()
	}
	
	func updateUI() {
		
		guard let article = currentArticle else {
			articleExtractorButton.isEnabled = false
			nextUnreadBarButtonItem.isEnabled = false
			prevArticleBarButtonItem.isEnabled = false
			nextArticleBarButtonItem.isEnabled = false
			readBarButtonItem.isEnabled = false
			starBarButtonItem.isEnabled = false
			browserBarButtonItem.isEnabled = false
			actionBarButtonItem.isEnabled = false
			return
		}
		
		nextUnreadBarButtonItem.isEnabled = coordinator.isAnyUnreadAvailable
		prevArticleBarButtonItem.isEnabled = coordinator.isPrevArticleAvailable
		nextArticleBarButtonItem.isEnabled = coordinator.isNextArticleAvailable

		articleExtractorButton.isEnabled = true
		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true
		browserBarButtonItem.isEnabled = true
		actionBarButtonItem.isEnabled = true

		let readImage = article.status.read ? AppAssets.circleOpenImage : AppAssets.circleClosedImage
		readBarButtonItem.image = readImage
		
		let starImage = article.status.starred ? AppAssets.starClosedImage : AppAssets.starOpenImage
		starBarButtonItem.image = starImage
		
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
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		case .extracted(let article, let extractedArticle):
			rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style)
		}
		
		let templateData = TemplateData(style: rendering.style, body: rendering.html)
		
		let encoder = JSONEncoder()
		var render = "error();"
		if let data = try? encoder.encode(templateData) {
			let json = String(data: data, encoding: .utf8)!
			render = "render(\(json));"
		}

		webView?.evaluateJavaScript(render)
		
	}
	
	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		if articles.count == 1 && articles.first?.articleID == currentArticle?.articleID {
			updateUI()
		}
	}

	@objc func progressDidChange(_ note: Notification) {
		updateProgressIndicatorIfNeeded()
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadHTML()
	}
	
	// Don't delete this even though it looks like it isn't doing anything.  This is to work
	// around a bug (don't know if it is an Apple one or ours) that happens when the root
	// split view controller is not collapsed.  When the app goes to the background and then
	// comes back to the foreground the article extractor button will disappear.  The
	// navigationItem will still have a reference to the articleExtractorButton, but if you
	// check in the view debugger, the button isn't in the view hierarchy anymore.
	// Setting the titleView to nil and then back to the articleExtractorButton hides that
	// this happened.  If we move the articleExtractorButton to someplace other than the
	// titleView, then this code can be safely deleted.
	@objc func willEnterForeground(_ note: Notification) {
		navigationItem.titleView = nil
		navigationItem.titleView = articleExtractorButton
	}
	
	// MARK: Actions
	
	@IBAction func toggleArticleExtractor(_ sender: Any) {
		coordinator.toggleArticleExtractor()
	}
	
	@IBAction func nextUnread(_ sender: Any) {
		coordinator.selectNextUnread()
	}
	
	@IBAction func prevArticle(_ sender: Any) {
		coordinator.selectPrevArticle()
	}
	
	@IBAction func nextArticle(_ sender: Any) {
		coordinator.selectNextArticle()
	}
	
	@IBAction func toggleRead(_ sender: Any) {
		coordinator.toggleReadForCurrentArticle()
	}
	
	@IBAction func toggleStar(_ sender: Any) {
		coordinator.toggleStarredForCurrentArticle()
	}
	
	@IBAction func openBrowser(_ sender: Any) {
		coordinator.showBrowserForCurrentArticle()
	}
	
	@IBAction func showActivityDialog(_ sender: Any) {
		guard let preferredLink = currentArticle?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		
		let itemSource = ArticleActivityItemSource(url: url, subject: currentArticle!.title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
		activityViewController.popoverPresentationController?.barButtonItem = actionBarButtonItem
		present(activityViewController, animated: true)
	}
	
	// MARK: Keyboard Shortcuts
	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}
	
	// MARK: API

	func focus() {
		webView.becomeFirstResponder()
	}

	func finalScrollPosition() -> CGFloat {
		return webView.scrollView.contentSize.height - webView.scrollView.bounds.size.height + webView.scrollView.contentInset.bottom
	}
	
	func canScrollDown() -> Bool {
		return webView.scrollView.contentOffset.y < finalScrollPosition()
	}

	func scrollPageDown() {
		let scrollToY: CGFloat = {
			let fullScroll = webView.scrollView.contentOffset.y + webView.scrollView.bounds.size.height
			let final = finalScrollPosition()
			return fullScroll < final ? fullScroll : final
		}()
		
		let convertedPoint = self.view.convert(CGPoint(x: 0, y: 0), to: webView.scrollView)
		let scrollToPoint = CGPoint(x: convertedPoint.x, y: scrollToY)
		webView.scrollView.setContentOffset(scrollToPoint, animated: true)
	}
	
	func hideClickedImage() {
		webView?.evaluateJavaScript("hideClickedImage();")
	}
	
	func showClickedImage(completion: @escaping () -> Void) {
		clickedImageCompletion = completion
		webView?.evaluateJavaScript("showClickedImage();")
	}
	
}

// MARK: WKNavigationDelegate

extension ArticleViewController: WKNavigationDelegate {
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		if navigationAction.navigationType == .linkActivated {
			
			guard let url = navigationAction.request.url else {
				decisionHandler(.allow)
				return
			}
			
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			if components?.scheme == "http" || components?.scheme == "https" {
				let vc = SFSafariViewController(url: url)
				present(vc, animated: true)
				decisionHandler(.cancel)
			} else {
				decisionHandler(.allow)
			}
			
		} else {
			
			decisionHandler(.allow)
			
		}
		
	}

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		self.updateUI()
		self.reloadHTML()
	}
	
}

// MARK: WKUIDelegate

extension ArticleViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo, willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
		// We need to have at least an unimplemented WKUIDelegate assigned to the WKWebView.  This makes the
		// link preview launch Safari when the link preview is tapped.  In theory, you shoud be able to get
		// the link from the elementInfo above and transition to SFSafariViewController instead of launching
		// Safari.  As the time of this writing, the link in elementInfo is always nil.  ¯\_(ツ)_/¯
	}
}

// MARK: WKScriptMessageHandler

extension ArticleViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		switch message.name {
		case MessageName.imageWasShown:
			clickedImageCompletion?()
		case MessageName.imageWasClicked:
			imageWasClicked(body: message.body as? String)
		default:
			return
		}
	}
	
}

class WrapperScriptMessageHandler: NSObject, WKScriptMessageHandler {
	
	// We need to wrap a message handler to prevent a circlular reference
	private weak var handler: WKScriptMessageHandler?
	
	init(_ handler: WKScriptMessageHandler) {
		self.handler = handler
	}
	
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		handler?.userContentController(userContentController, didReceive: message)
	}
	
}

// MARK: UIViewControllerTransitioningDelegate

extension ArticleViewController: UIViewControllerTransitioningDelegate {

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		transition.presenting = true
		return transition
	}
	
	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		transition.presenting = false
		return transition
	}
}

// MARK: JSON

private struct TemplateData: Codable {
	let style: String
	let body: String
}

private struct ImageClickMessage: Codable {
	let x: Float
	let y: Float
	let width: Float
	let height: Float
	let imageURL: String
}

// MARK: Private

private extension ArticleViewController {
	
	func updateProgressIndicatorIfNeeded() {
		if !(UIDevice.current.userInterfaceIdiom == .pad) {
			navigationController?.updateAccountRefreshProgressIndicator()
		}
	}
	
	func imageWasClicked(body: String?) {
		guard let body = body,
			let data = body.data(using: .utf8),
			let clickMessage = try? JSONDecoder().decode(ImageClickMessage.self, from: data),
			let range = clickMessage.imageURL.range(of: ";base64,")
			else { return }
		
		let base64Image = String(clickMessage.imageURL.suffix(from: range.upperBound))
		if let imageData = Data(base64Encoded: base64Image), let image = UIImage(data: imageData) {
			let rect = CGRect(x: CGFloat(clickMessage.x), y: CGFloat(clickMessage.y), width: CGFloat(clickMessage.width), height: CGFloat(clickMessage.height))
			transition.originFrame = webView.convert(rect, to: nil)
			transition.maskFrame = webView.convert(webView.frame, to: nil)
			transition.originImage = image
			
			coordinator.showFullScreenImage(image: image, transitioningDelegate: self)
		}
	}
	
}
