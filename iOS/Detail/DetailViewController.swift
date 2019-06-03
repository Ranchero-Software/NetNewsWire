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

	@IBOutlet weak var nextUnreadBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var prevArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var nextArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var actionBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var browserBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var webView: WKWebView!
	
	weak var navState: NavigationStateController?
	
	override func viewDidLoad() {
		
		super.viewDidLoad()
		webView.navigationDelegate = self
		
		markAsRead()
		updateUI()
		reloadHTML()
		
		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(articleSelectionDidChange(_:)), name: .ArticleSelectionDidChange, object: navState)
		NotificationCenter.default.addObserver(self, selector: #selector(progressDidChange(_:)), name: .AccountRefreshProgressDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		updateProgressIndicatorIfNeeded()
	}
	
	func markAsRead() {
		if let article = navState?.currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: true)
		}
	}
	
	func updateUI() {
		
		guard let article = navState?.currentArticle else {
			nextUnreadBarButtonItem.isEnabled = false
			prevArticleBarButtonItem.isEnabled = false
			nextArticleBarButtonItem.isEnabled = false
			readBarButtonItem.isEnabled = false
			starBarButtonItem.isEnabled = false
			browserBarButtonItem.isEnabled = false
			actionBarButtonItem.isEnabled = false
			return
		}
		
		nextUnreadBarButtonItem.isEnabled = navState?.isAnyUnreadAvailable ?? false
		prevArticleBarButtonItem.isEnabled = navState?.isPrevArticleAvailable ?? false
		nextArticleBarButtonItem.isEnabled = navState?.isNextArticleAvailable ?? false

		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true
		browserBarButtonItem.isEnabled = true
		actionBarButtonItem.isEnabled = true

		let readImage = article.status.read ? AppAssets.circleOpenImage : AppAssets.circleClosedImage
		readBarButtonItem.image = readImage
		
		let starImage = article.status.starred ? AppAssets.starClosedImage : AppAssets.starOpenImage
		starBarButtonItem.image = starImage
		
		if let timelineName = navState?.timelineName {
			if navigationController?.navigationItem.backBarButtonItem?.title != timelineName {
				let backItem = UIBarButtonItem(title: timelineName, style: .plain, target: nil, action: nil)
				navigationController?.navigationItem.backBarButtonItem = backItem
			}
		}
		
	}
	
	func reloadHTML() {
		
		guard let article = navState?.currentArticle, let webView = webView else {
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
		if articles.count == 1 && articles.first?.articleID == navState?.currentArticle?.articleID {
			updateUI()
		}
	}

	@objc func articleSelectionDidChange(_ note: Notification) {
		markAsRead()
		updateUI()
		reloadHTML()
	}

	@objc func progressDidChange(_ note: Notification) {
		updateProgressIndicatorIfNeeded()
	}
	
	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadHTML()
	}
	
	// MARK: Actions
	
	@IBAction func nextUnread(_ sender: Any) {
		navState?.selectNextUnread()
	}
	
	@IBAction func prevArticle(_ sender: Any) {
		navState?.currentArticleIndexPath = navState?.prevArticleIndexPath
	}
	
	@IBAction func nextArticle(_ sender: Any) {
		navState?.currentArticleIndexPath = navState?.nextArticleIndexPath
	}
	
	@IBAction func toggleRead(_ sender: Any) {
		if let article = navState?.currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: !article.status.read)
		}
	}
	
	@IBAction func toggleStar(_ sender: Any) {
		if let article = navState?.currentArticle {
			markArticles(Set([article]), statusKey: .starred, flag: !article.status.starred)
		}
	}
	
	@IBAction func openBrowser(_ sender: Any) {
		guard let preferredLink = navState?.currentArticle?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		UIApplication.shared.open(url, options: [:])
	}
	
	@IBAction func showActivityDialog(_ sender: Any) {
		guard let preferredLink = navState?.currentArticle?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		let itemSource = ArticleActivityItemSource(url: url, subject: navState?.currentArticle?.title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
		activityViewController.popoverPresentationController?.barButtonItem = self.actionBarButtonItem
		
		present(activityViewController, animated: true)
	}
	
}

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
