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
		self.navigationController?.navigationItem.largeTitleDisplayMode = .never
		webView.navigationDelegate = self
		markAsRead()
		reloadUI()
		reloadHTML()
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(articleSelectionDidChange(_:)), name: .ArticleSelectionDidChange, object: navState)
	}

	func markAsRead() {
		if let article = navState?.currentArticle {
			markArticles(Set([article]), statusKey: .read, flag: true)
		}
	}
	
	func reloadUI() {
		
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
		
		nextArticleBarButtonItem.isEnabled = false
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
		
	}
	
	func reloadHTML() {
		
		guard let article = navState?.currentArticle, let webView = webView else {
			return
		}
		let style = ArticleStylesManager.shared.currentStyle
		let html = ArticleRenderer.articleHTML(article: article, style: style)
		webView.loadHTMLString(html, baseURL: nil)
		
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		if articles.count == 1 && articles.first?.articleID == navState?.currentArticle?.articleID {
			reloadUI()
		}
	}

	@objc func articleSelectionDidChange(_ note: Notification) {
		markAsRead()
		reloadUI()
		reloadHTML()
	}
	
	// MARK: Actions
	
	@IBAction func nextUnread(_ sender: Any) {
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
