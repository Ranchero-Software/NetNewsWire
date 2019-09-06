//
//  DetailViewController.swift
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

class DetailViewController: UIViewController {

	@IBOutlet private weak var nextUnreadBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var prevArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var nextArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var actionBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var browserBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var webViewContainer: UIView!
	private var webView: WKWebView!

	weak var coordinator: SceneCoordinator!
	
	private let keyboardManager = KeyboardManager(type: .detail)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	deinit {
		webView.removeFromSuperview()
		DetailViewControllerWebViewProvider.shared.enqueueWebView(webView)
		webView = nil
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		webView = DetailViewControllerWebViewProvider.shared.dequeueWebView()
		webView.translatesAutoresizingMaskIntoConstraints = false
		webView.navigationDelegate = self
		
		webViewContainer.addSubview(webView)
		
		let constraints: [NSLayoutConstraint] = [
			webView.leadingAnchor.constraint(equalTo: webViewContainer.safeAreaLayoutGuide.leadingAnchor),
			webView.trailingAnchor.constraint(equalTo: webViewContainer.safeAreaLayoutGuide.trailingAnchor),
			webView.topAnchor.constraint(equalTo: webViewContainer.safeAreaLayoutGuide.topAnchor),
			webView.bottomAnchor.constraint(equalTo: webViewContainer.safeAreaLayoutGuide.bottomAnchor),
		]
		
		NSLayoutConstraint.activate(constraints)

		updateArticleSelection()
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateProgressIndicatorIfNeeded()
	}
	
	func updateUI() {
		
		guard let article = coordinator.currentArticle else {
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
		
		guard let article = coordinator.currentArticle, let webView = webView else {
			return
		}
		let style = ArticleStylesManager.shared.currentStyle
		let html = ArticleRenderer.articleHTML(article: article, style: style)
		webView.loadHTMLString(html, baseURL: nil)
		
	}
	
	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		if articles.count == 1 && articles.first?.articleID == coordinator.currentArticle?.articleID {
			updateUI()
		}
	}

	@objc func progressDidChange(_ note: Notification) {
		updateProgressIndicatorIfNeeded()
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadHTML()
	}
	
	// MARK: Actions
	
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
		guard let currentArticle = coordinator.currentArticle, let preferredLink = currentArticle.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		
		let itemSource = ArticleActivityItemSource(url: url, subject: currentArticle.title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
		activityViewController.popoverPresentationController?.barButtonItem = actionBarButtonItem
		present(activityViewController, animated: true)
	}
	
	// MARK: Keyboard Shortcuts
	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}
	
	// MARK: API
	func updateArticleSelection() {
		updateUI()
		reloadHTML()
	}

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
	
}
//print("\(candidateY) : \(webView.scrollView.contentSize.height)")

class ArticleActivityItemSource: NSObject, UIActivityItemSource {
	
	private let url: URL
	private let subject: String?
	
	init(url: URL, subject: String?) {
		self.url = url
		self.subject = subject
	}
	
	func activityViewControllerPlaceholderItem(_ : UIActivityViewController) -> Any {
		return url
	}
	
	func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
		return url
	}
	
	func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
		return subject ?? ""
	}
	
}

extension DetailViewController: WKNavigationDelegate {
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
}

private extension DetailViewController {
	
	func updateProgressIndicatorIfNeeded() {
		if !(UIDevice.current.userInterfaceIdiom == .pad) {
			navigationController?.updateAccountRefreshProgressIndicator()
		}
	}
	
}

// MARK: -

/// WKWebView has an awful behavior of a flash to white on first load when in dark mode.
/// Keep a queue of WebViews where we've already done a trivial load so that by the time we need them in the UI, they're past the flash-to-shite part of their lifecycle.
class DetailViewControllerWebViewProvider {
	static var shared = DetailViewControllerWebViewProvider()
	
	func dequeueWebView() -> WKWebView {
		if let webView = queue.popLast() {
			replenishQueueIfNeeded()
			return webView
		}
		
		assertionFailure("Creating WKWebView in \(#function); queue has run dry.")
		let webView = WKWebView(frame: .zero)
		return webView
	}
	
	func enqueueWebView(_ webView: WKWebView) {
		guard queue.count < maximumQueueDepth else {
			return
		}

		webView.uiDelegate = nil
		webView.navigationDelegate = nil

		let html = ArticleRenderer.noContentHTML(style: .defaultStyle)
		webView.loadHTMLString(html, baseURL: nil)

		queue.insert(webView, at: 0)
	}

	// MARK: Private

	private let minimumQueueDepth = 3
	private let maximumQueueDepth = 6
	private var queue: [WKWebView] = []
	
	private init() {
		replenishQueueIfNeeded()
	}
	
	private func replenishQueueIfNeeded() {
		while queue.count < minimumQueueDepth {
			let webView = WKWebView(frame: .zero)
			enqueueWebView(webView)
		}
	}
}
