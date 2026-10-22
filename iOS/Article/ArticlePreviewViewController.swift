//
//  ArticlePreviewViewController.swift
//  NetNewsWire-iOS
//
//  Created by Brent Simmons on 10/21/26.
//  Copyright © 2026 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Articles

/// Read-only rendering of an article for the timeline context menu preview.
final class ArticlePreviewViewController: UIViewController {
	let article: Article
	private let articleIconSchemeHandler: ArticleIconSchemeHandler
	private var webView: WKWebView?

	init(article: Article, coordinator: SceneCoordinator) {
		self.article = article
		self.articleIconSchemeHandler = ArticleIconSchemeHandler(coordinator: coordinator)
		super.init(nibName: nil, bundle: nil)
	}

	required init?(coder: NSCoder) {
		nil
	}

	override func loadView() {
		let configuration = WebViewConfiguration.configuration(with: articleIconSchemeHandler)
		configuration.defaultWebpagePreferences.allowsContentJavaScript = WebViewConfiguration.allowsContentJavaScript(for: article)

		let webView = WKWebView(frame: .zero, configuration: configuration)
		webView.isUserInteractionEnabled = false
		// Avoids a flash of white in dark mode before the page loads.
		webView.isOpaque = false
		webView.backgroundColor = .systemBackground
		webView.scrollView.backgroundColor = .systemBackground
		WebViewConfiguration.addContentBlockingRules(to: webView)

		self.webView = webView
		view = webView
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		let rendering = ArticleRenderer.articleHTML(article: article, theme: ArticleThemesManager.shared.currentTheme)
		let html = ArticleRenderer.pageHTML(rendering, windowScrollY: 0)
		webView?.loadHTMLString(html, baseURL: URL(string: rendering.baseURL))
	}
}
