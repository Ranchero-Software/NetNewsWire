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

class DetailViewController: UIViewController {

	@IBOutlet weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var actionBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var browserBarButtonItem: UIBarButtonItem!
	@IBOutlet weak var webView: WKWebView!
	
	var article: Article? {
		didSet {
			reloadUI()
			reloadHTML()
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		self.navigationController?.navigationItem.largeTitleDisplayMode = .never
		webView.navigationDelegate = self
		reloadUI()
		reloadHTML()
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
	}

	func reloadUI() {
		
		guard let article = article else {
			readBarButtonItem.isEnabled = false
			starBarButtonItem.isEnabled = false
			browserBarButtonItem.isEnabled = false
			actionBarButtonItem.isEnabled = false
			return
		}
		
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
		guard let article = article, let webView = webView else {
			return
		}
		let style = ArticleStylesManager.shared.currentStyle
		let html = ArticleRenderer.articleHTML(article: article, style: style)
		webView.loadHTMLString(html, baseURL: article.baseURL)
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articles = note.userInfo?[Account.UserInfoKey.articles] as? Set<Article> else {
			return
		}
		if articles.count == 1 && articles.first?.articleID == article?.articleID {
			reloadUI()
		}
	}

	@IBAction func toggleRead(_ sender: Any) {
		if let article = article {
			markArticles(Set([article]), statusKey: .read, flag: !article.status.read)
		}
	}
	
	@IBAction func toggleStar(_ sender: Any) {
		if let article = article {
			markArticles(Set([article]), statusKey: .starred, flag: !article.status.starred)
		}
	}
	
	@IBAction func openBrowser(_ sender: Any) {
		guard let preferredLink = article?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		UIApplication.shared.open(url, options: [:])
	}
	
	@IBAction func showActivityDialog(_ sender: Any) {
		guard let preferredLink = article?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		let itemSource = ArticleActivityItemSource(url: url, subject: article?.title)
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
				UIApplication.shared.open(url)
				decisionHandler(.cancel)
			} else {
				decisionHandler(.allow)
			}
			
		} else {
			
			decisionHandler(.allow)
			
		}
		
	}
}

private extension Article {
	
	var baseURL: URL? {
		var s = url
		if s == nil {
			s = feed?.homePageURL
		}
		if s == nil {
			s = feed?.url
		}
		
		guard let urlString = s else {
			return nil
		}
		var urlComponents = URLComponents(string: urlString)
		if urlComponents == nil {
			return nil
		}
		
		// Can’t use url-with-fragment as base URL. The webview won’t load. See scripting.com/rss.xml for example.
		urlComponents!.fragment = nil
		guard let url = urlComponents!.url, url.scheme == "http" || url.scheme == "https" else {
			return nil
		}
		return url
	}
	
}
