//
//  PreloadedWebView.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 2/25/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import Foundation
import UIKit
import WebKit

@MainActor protocol PreloadedWebViewDelegate: AnyObject {
	var articleURL: URL? { get }
	func getSelectedText(completion: @escaping (String?) -> Void)
}

final class PreloadedWebView: WKWebView {

	weak var editMenuDelegate: PreloadedWebViewDelegate?

	private var isReady: Bool = false
	private var readyCompletion: (() -> Void)?

	init(articleIconSchemeHandler: ArticleIconSchemeHandler) {
		let configuration = WebViewConfiguration.configuration(with: articleIconSchemeHandler)
		super.init(frame: .zero, configuration: configuration)
		NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
			Task { @MainActor in
				self?.userDefaultsDidChange()
			}
		}
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)

	}

	func preload() {
		navigationDelegate = self
		loadFileURL(ArticleRenderer.blank.url, allowingReadAccessTo: ArticleRenderer.blank.baseURL)
	}

	func ready(completion: @escaping () -> Void) {
		if isReady {
			completeRequest(completion: completion)
		} else {
			readyCompletion = completion
		}
	}

	func userDefaultsDidChange() {
		if configuration.defaultWebpagePreferences.allowsContentJavaScript != AppDefaults.shared.isArticleContentJavascriptEnabled {
			configuration.defaultWebpagePreferences.allowsContentJavaScript = AppDefaults.shared.isArticleContentJavascriptEnabled
			reload()
		}
	}

	override func buildMenu(with builder: any UIMenuBuilder) {
		super.buildMenu(with: builder)

		guard builder.system == .context else {
			return
		}

		let copyLinkAction = UIAction(
			title: NSLocalizedString("Copy Link with Highlight", comment: "Copy Link with Highlight"),
			image: UIImage(systemName: "link")
		) { [weak self] _ in
			self?.copyLinkWithHighlight()
		}

		let menu = UIMenu(title: "", options: .displayInline, children: [copyLinkAction])
		builder.insertSibling(menu, afterMenu: .lookup)
	}
}

// MARK: WKScriptMessageHandler

extension PreloadedWebView: WKNavigationDelegate {

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		isReady = true
		if let completion = readyCompletion {
			completeRequest(completion: completion)
			readyCompletion = nil
		}
	}
}

// MARK: Private

private extension PreloadedWebView {

	func completeRequest(completion: @escaping () -> Void) {
		isReady = false
		navigationDelegate = nil
		completion()
	}

	func copyLinkWithHighlight() {
		guard let delegate = editMenuDelegate, let baseURL = delegate.articleURL else {
			return
		}

		delegate.getSelectedText { selectedText in
			let urlToCopy: URL
			if let selectedText, !selectedText.isEmpty,
			   let textFragmentURL = TextFragmentURL.url(from: baseURL, selectedText: selectedText) {
				urlToCopy = textFragmentURL
			} else {
				urlToCopy = baseURL
			}
			UIPasteboard.general.url = urlToCopy
		}
	}
}
