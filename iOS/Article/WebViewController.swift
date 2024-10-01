//
//  WebViewController.swift
//  NetNewsWire-iOS
//
//  Created by Maurice Parker on 12/28/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import Account
import Articles
import SafariServices
import MessageUI
import Core
import ArticleExtractor
import Images
import Web

protocol WebViewControllerDelegate: AnyObject {
	
	@MainActor func webViewController(_: WebViewController, articleExtractorButtonStateDidUpdate: ArticleExtractorButtonState)
}

final class WebViewController: UIViewController {
	
	private struct MessageName {
		static let imageWasClicked = "imageWasClicked"
		static let imageWasShown = "imageWasShown"
		static let showFeedInspector = "showFeedInspector"
	}

	private var topShowBarsView: UIView!
	private var bottomShowBarsView: UIView!
	private var topShowBarsViewConstraint: NSLayoutConstraint!
	private var bottomShowBarsViewConstraint: NSLayoutConstraint!
	
	var webView: WKWebView? {
		return view.subviews[0] as? WKWebView
	}

	private lazy var contextMenuInteraction = UIContextMenuInteraction(delegate: self)
	private var isFullScreenAvailable: Bool {
		return AppDefaults.shared.articleFullscreenAvailable && traitCollection.userInterfaceIdiom == .phone && coordinator.isRootSplitCollapsed
	}
	private lazy var articleIconSchemeHandler = ArticleIconSchemeHandler(delegate: self);
	private lazy var transition = ImageTransition(controller: self)
	private var clickedImageCompletion: (() -> Void)?

	private var articleExtractor: ArticleExtractor? = nil
	var extractedArticle: ExtractedArticle? {
		didSet {
			windowScrollY = 0
		}
	}
	var isShowingExtractedArticle = false

	var articleExtractorButtonState: ArticleExtractorButtonState = .off {
		didSet {
			delegate?.webViewController(self, articleExtractorButtonStateDidUpdate: articleExtractorButtonState)
		}
	}
	
	weak var coordinator: SceneCoordinator!
	weak var delegate: WebViewControllerDelegate?
	
	private(set) var article: Article?
	
	let scrollPositionQueue = CoalescingQueue(name: "Article Scroll Position", interval: 0.3)
	var windowScrollY = 0
	private var restoreWindowScrollY: Int?

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(feedIconDidBecomeAvailable(_:)), name: .FeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(currentArticleThemeDidChangeNotification(_:)), name: .CurrentArticleThemeDidChangeNotification, object: nil)

		// Configure the tap zones
		configureTopShowBarsView()
		configureBottomShowBarsView()
		
		loadWebView()

	}
	
	override func viewWillAppear(_ animated: Bool) {
		updateScrollIndicatorStyle()
	}
	
	override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
		updateScrollIndicatorStyle()
	}
	
	
	// See https://shadowfacts.net/2022/wkwebview-scroll-indicators-again/ for why this is necessary.
	private func updateScrollIndicatorStyle() {
		guard #available(iOS 15.4, *) else {
			return
		}
		
		if traitCollection.userInterfaceStyle == .dark {
			webView?.scrollView.indicatorStyle = .white
		} else {
			webView?.scrollView.indicatorStyle = .black
		}
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

	@objc func currentArticleThemeDidChangeNotification(_ note: Notification) {
		loadWebView()
	}

	// MARK: Actions
	
	@objc func showBars(_ sender: Any) {
		showBars()
	}
	
	// MARK: API

	func setArticle(_ article: Article?, updateView: Bool = true) {
		stopArticleExtractor()
		
		if article != self.article {
			self.article = article
			if updateView {
				if article?.feed?.isArticleExtractorAlwaysOn ?? false {
					startArticleExtractor()
				}
				windowScrollY = 0
				loadWebView()
			}
		}
		
	}
	
	func setScrollPosition(isShowingExtractedArticle: Bool, articleWindowScrollY: Int) {
		if isShowingExtractedArticle {
			switch articleExtractor?.state {
			case .ready:
				restoreWindowScrollY = articleWindowScrollY
				startArticleExtractor()
			case .complete:
				windowScrollY = articleWindowScrollY
				loadWebView()
			case .processing:
				restoreWindowScrollY = articleWindowScrollY
			default:
				restoreWindowScrollY = articleWindowScrollY
				startArticleExtractor()
			}
		} else {
			windowScrollY = articleWindowScrollY
			loadWebView()
		}
	}
	
	func focus() {
		webView?.becomeFirstResponder()
	}

	func canScrollDown() -> Bool {
		guard let webView = webView else { return false }
		return webView.scrollView.contentOffset.y < finalScrollPosition(scrollingUp: false)
	}

	func canScrollUp() -> Bool {
		guard let webView = webView else { return false }
		return webView.scrollView.contentOffset.y > finalScrollPosition(scrollingUp: true)
	}

	private func scrollPage(up scrollingUp: Bool) {
		guard let webView = webView else { return }

		let overlap = 2 * UIFont.systemFont(ofSize: UIFont.systemFontSize).lineHeight * UIScreen.main.scale
		let scrollToY: CGFloat = {
			let scrollDistance = webView.scrollView.layoutMarginsGuide.layoutFrame.height - overlap;
			let fullScroll = webView.scrollView.contentOffset.y + (scrollingUp ? -scrollDistance : scrollDistance)
			let final = finalScrollPosition(scrollingUp: scrollingUp)
			return (scrollingUp ? fullScroll > final : fullScroll < final) ? fullScroll : final
		}()

		let convertedPoint = self.view.convert(CGPoint(x: 0, y: 0), to: webView.scrollView)
		let scrollToPoint = CGPoint(x: convertedPoint.x, y: scrollToY)
		webView.scrollView.setContentOffset(scrollToPoint, animated: true)
	}

	func scrollPageDown() {
		scrollPage(up: false)
	}

	func scrollPageUp() {
		scrollPage(up: true)
	}

	func hideClickedImage() {
		webView?.evaluateJavaScript("hideClickedImage();")
	}
	
	func showClickedImage(completion: @escaping () -> Void) {
		clickedImageCompletion = completion
		webView?.evaluateJavaScript("showClickedImage();")
	}
	
	func fullReload() {
		loadWebView(replaceExistingWebView: true)
	}

	func showBars() {
		AppDefaults.shared.articleFullscreenEnabled = false
		coordinator.showStatusBar()
		topShowBarsViewConstraint?.constant = 0
		bottomShowBarsViewConstraint?.constant = 0
		navigationController?.setNavigationBarHidden(false, animated: true)
		navigationController?.setToolbarHidden(false, animated: true)
		configureContextMenuInteraction()
	}
		
	func hideBars() {
		if isFullScreenAvailable {
			AppDefaults.shared.articleFullscreenEnabled = true
			coordinator.hideStatusBar()
			topShowBarsViewConstraint?.constant = -44.0
			bottomShowBarsViewConstraint?.constant = 44.0
			navigationController?.setNavigationBarHidden(true, animated: true)
			navigationController?.setToolbarHidden(true, animated: true)
			configureContextMenuInteraction()
		}
	}

	func toggleArticleExtractor() {

		guard let article = article else {
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
			cancelImageLoad(webView)
		}
	}
	
	func showActivityDialog(popOverBarButtonItem: UIBarButtonItem? = nil) {
		guard let url = article?.preferredURL else { return }
		let activityViewController = UIActivityViewController(url: url, title: article?.title, applicationActivities: [FindInArticleActivity(), OpenInBrowserActivity()])
		activityViewController.popoverPresentationController?.barButtonItem = popOverBarButtonItem
		present(activityViewController, animated: true)
	}

	func openInAppBrowser() {
		guard let url = article?.preferredURL else { return }
		if AppDefaults.shared.useSystemBrowser {
			UIApplication.shared.open(url, options: [:])
		} else {
			let vc = SFSafariViewController(url: url)
			present(vc, animated: true)
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
			if let restoreWindowScrollY = restoreWindowScrollY {
				windowScrollY = restoreWindowScrollY
			}
			isShowingExtractedArticle = true
			loadWebView()
			articleExtractorButtonState = .on
		}
	}

}


// MARK: ArticleIconSchemeHandlerDelegate

extension WebViewController: ArticleIconSchemeHandlerDelegate {

	func iconImage(for articleID: String) -> IconImage? {
		coordinator.articleFor(articleID)?.iconImage()
	}
}

// MARK: UIContextMenuInteractionDelegate

extension WebViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
	
		return UIContextMenuConfiguration(identifier: nil, previewProvider: contextMenuPreviewProvider) { [weak self] suggestedActions in
			guard let self = self else { return nil }

			var menus = [UIMenu]()
			
			var navActions = [UIAction]()
			if let action = self.prevArticleAction() {
				navActions.append(action)
			}
			if let action = self.nextArticleAction() {
				navActions.append(action)
			}
			if !navActions.isEmpty {
				menus.append(UIMenu(title: "", options: .displayInline, children: navActions))
			}
			
			var toggleActions = [UIAction]()
			if let action = self.toggleReadAction() {
				toggleActions.append(action)
			}
			toggleActions.append(self.toggleStarredAction())
			menus.append(UIMenu(title: "", options: .displayInline, children: toggleActions))

			if let action = self.nextUnreadArticleAction() {
				menus.append(UIMenu(title: "", options: .displayInline, children: [action]))
			}

			menus.append(UIMenu(title: "", options: .displayInline, children: [self.toggleArticleExtractorAction()]))
			menus.append(UIMenu(title: "", options: .displayInline, children: [self.shareAction()]))
			
			return UIMenu(title: "", children: menus)
        }
    }
	
	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
		coordinator.showBrowserForCurrentArticle()
	}
	
}

// MARK: WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
	
	nonisolated func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {

		guard navigationAction.navigationType == .linkActivated else {
			decisionHandler(.allow)
			return
		}
		guard let url = navigationAction.request.url else {
			decisionHandler(.allow)
			return
		}
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false), let scheme = components.scheme else {
			decisionHandler(.allow)
			return
		}

		switch scheme {

		case URLScheme.http, URLScheme.https:
			decisionHandler(.cancel)
			openURLInBrowser(url)

		case URLScheme.mailto:
			decisionHandler(.cancel)
			guard let emailAddressURL = url.percentEncodedEmailAddress else {
				return
			}
			openEmailAddressURL(emailAddressURL)

		case URLScheme.tel:
			decisionHandler(.cancel)
			openTelURL(url)

		default:
			decisionHandler(.allow)
		}
	}

	nonisolated func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {

		Task { @MainActor in
			fullReload()
		}
	}

	nonisolated private func openURLInBrowser(_ url: URL) {

		Task { @MainActor in
			if AppDefaults.shared.useSystemBrowser {
				UIApplication.shared.open(url, options: [:])
			} else {
				UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { didOpen in
					guard didOpen == false else {
						return
					}
					let vc = SFSafariViewController(url: url)
					self.present(vc, animated: true)
				}
			}
		}
	}

	nonisolated private func openEmailAddressURL(_ url: URL) {

		Task { @MainActor in
			if UIApplication.shared.canOpenURL(url) {
				UIApplication.shared.open(url, options: [.universalLinksOnly : false], completionHandler: nil)
			} else {
				let alert = UIAlertController(title: NSLocalizedString("Error", comment: "Error"), message: NSLocalizedString("This device cannot send emails.", comment: "This device cannot send emails."), preferredStyle: .alert)
				alert.addAction(.init(title: NSLocalizedString("Dismiss", comment: "Dismiss"), style: .cancel, handler: nil))
				self.present(alert, animated: true, completion: nil)
			}
		}
	}

	nonisolated private func openTelURL(_ url: URL) {

		Task { @MainActor in
			if UIApplication.shared.canOpenURL(url) {
				UIApplication.shared.open(url, options: [.universalLinksOnly : false], completionHandler: nil)
			}
		}
	}
}

// MARK: WKUIDelegate

extension WebViewController: WKUIDelegate {
	
	nonisolated func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo, willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
		// We need to have at least an unimplemented WKUIDelegate assigned to the WKWebView.  This makes the
		// link preview launch Safari when the link preview is tapped.  In theory, you should be able to get
		// the link from the elementInfo above and transition to SFSafariViewController instead of launching
		// Safari.  As the time of this writing, the link in elementInfo is always nil.  ¯\_(ツ)_/¯
	}

	nonisolated func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		guard let url = navigationAction.request.url else {
			return nil
		}
		
		Task { @MainActor in
			openURL(url)
		}

		return nil
	}
	
}

// MARK: WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {

	nonisolated func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {

		let name = message.name
		let body = message.body as? String

		Task { @MainActor in
			switch name {
			case MessageName.imageWasShown:
				clickedImageCompletion?()
			case MessageName.imageWasClicked:
				imageWasClicked(body: body)
			case MessageName.showFeedInspector:
				if let feed = article?.feed {
					coordinator.showFeedInspector(for: feed)
				}
			default:
				return
			}
		}
	}
	
}

// MARK: UIViewControllerTransitioningDelegate

extension WebViewController: UIViewControllerTransitioningDelegate {

	func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		transition.presenting = true
		return transition
	}
	
	func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		transition.presenting = false
		return transition
	}
}

// MARK:

extension WebViewController: UIScrollViewDelegate {
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		scrollPositionQueue.add(self, #selector(scrollPositionDidChange))
	}
	
	@objc func scrollPositionDidChange() {
		webView?.evaluateJavaScript("window.scrollY") { (scrollY, error) in
			guard error == nil else { return }
			let javascriptScrollY = scrollY as? Int ?? 0
			// I don't know why this value gets returned sometimes, but it is in error
			guard javascriptScrollY != 33554432 else { return }
			self.windowScrollY = javascriptScrollY
		}
	}
	
}



// MARK: JSON

private struct ImageClickMessage: Codable {
	let x: Float
	let y: Float
	let width: Float
	let height: Float
	let imageTitle: String?
	let imageURL: String
}

// MARK: Private

private extension WebViewController {

	func loadWebView(replaceExistingWebView: Bool = false) {
		guard isViewLoaded else { return }

		if !replaceExistingWebView, let webView = webView {
			self.renderPage(webView)
			return
		}

		let preferences = WKPreferences()
		preferences.javaScriptCanOpenWindowsAutomatically = false

		/// The defaults for `preferredContentMode` and `allowsContentJavaScript` are suitable
		/// and don't need to be explicitly set.
		/// `allowsContentJavaScript` replaces `WKPreferences.javascriptEnabled`.
		let webpagePreferences = WKWebpagePreferences()

		let configuration = WKWebViewConfiguration()
		configuration.defaultWebpagePreferences = webpagePreferences
		configuration.preferences = preferences
		configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
		configuration.allowsInlineMediaPlayback = true
		configuration.mediaTypesRequiringUserActionForPlayback = .audio
		if #available(iOS 15.4, *) {
			configuration.preferences.isElementFullscreenEnabled = true
		}
		configuration.setURLSchemeHandler(articleIconSchemeHandler, forURLScheme: ArticleRenderer.imageIconScheme)

		let userContentController = WKUserContentController()
		let baseURL = ArticleRenderer.page.baseURL
		let appScriptsWorld = WKContentWorld.world(name: "NetNewsWire")
		for fileName in ["main.js", "main_ios.js", "newsfoot.js"] {
			userContentController.addUserScript(
				.init(source: try! String(contentsOf: baseURL.appending(path: fileName,
																		directoryHint: .notDirectory)),
					  injectionTime: .atDocumentStart,
					  forMainFrameOnly: true,
					  in: appScriptsWorld))
		}

		configuration.userContentController = userContentController

		let webView = WKWebView(frame: self.view.bounds, configuration: configuration)
		webView.isOpaque = false;
		webView.backgroundColor = .clear;

		// Add the webview - using autolayout will cause fullscreen video to fail and lose the web view
		webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		self.view.insertSubview(webView, at: 0)

		// UISplitViewController reports the wrong size to WKWebView which can cause horizontal
		// rubberbanding on the iPad.  This interferes with our UIPageViewController preventing
		// us from easily swiping between WKWebViews.  This hack fixes that.
		webView.scrollView.contentInset = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: 0)

		webView.scrollView.setZoomScale(1.0, animated: false)

		self.view.setNeedsLayout()
		self.view.layoutIfNeeded()

		// Configure the webview
		webView.navigationDelegate = self
		webView.uiDelegate = self
		webView.scrollView.delegate = self
		self.configureContextMenuInteraction()

		webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
		webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)
		webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.showFeedInspector)

		self.renderPage(webView)
	}

	func renderPage(_ webView: WKWebView?) {
		guard let webView = webView else { return }
		 
		let theme = ArticleThemesManager.shared.currentTheme
		let rendering: ArticleRenderer.Rendering

		if let articleExtractor = articleExtractor, articleExtractor.state == .processing {
			rendering = ArticleRenderer.loadingHTML(theme: theme)
		} else if let articleExtractor = articleExtractor, articleExtractor.state == .failedToParse, let article = article {
			rendering = ArticleRenderer.articleHTML(article: article, theme: theme)
		} else if let article = article, let extractedArticle = extractedArticle {
			if isShowingExtractedArticle {
				rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, theme: theme)
			} else {
				rendering = ArticleRenderer.articleHTML(article: article, theme: theme)
			}
		} else if let article = article {
			rendering = ArticleRenderer.articleHTML(article: article, theme: theme)
		} else {
			rendering = ArticleRenderer.noSelectionHTML(theme: theme)
		}
		
		let substitutions = [
			"title": rendering.title,
			"baseURL": rendering.baseURL,
			"style": rendering.style,
			"body": rendering.html,
			"windowScrollY": String(windowScrollY)
		]

		let html = try! MacroProcessor.renderedText(withTemplate: ArticleRenderer.page.html, substitutions: substitutions)
		webView.loadHTMLString(html, baseURL: URL(string: rendering.baseURL))
		
	}
	
	func finalScrollPosition(scrollingUp: Bool) -> CGFloat {
		guard let webView = webView else { return 0 }

		if scrollingUp {
			return -webView.scrollView.safeAreaInsets.top
		} else {
			return webView.scrollView.contentSize.height - webView.scrollView.bounds.height + webView.scrollView.safeAreaInsets.bottom
		}
	}
	
	func startArticleExtractor() {
		guard articleExtractor == nil else { return }
		if let link = article?.preferredLink, let extractor = ArticleExtractor(link) {
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
		guard let article = article else { return }

		var components = URLComponents()
		components.scheme = ArticleRenderer.imageIconScheme
		components.path = article.articleID
		
		if let imageSrc = components.string {
			webView?.evaluateJavaScript("reloadArticleImage(\"\(imageSrc)\")")
		}
	}
	
	func imageWasClicked(body: String?) {
		guard let webView = webView,
			let body = body,
			let data = body.data(using: .utf8),
			let clickMessage = try? JSONDecoder().decode(ImageClickMessage.self, from: data),
			let range = clickMessage.imageURL.range(of: ";base64,")
			else { return }
		
		let base64Image = String(clickMessage.imageURL.suffix(from: range.upperBound))
		if let imageData = Data(base64Encoded: base64Image), let image = UIImage(data: imageData) {
			
			let y = CGFloat(clickMessage.y) + webView.safeAreaInsets.top
			let rect = CGRect(x: CGFloat(clickMessage.x), y: y, width: CGFloat(clickMessage.width), height: CGFloat(clickMessage.height))
			transition.originFrame = webView.convert(rect, to: nil)
			
			if navigationController?.navigationBar.isHidden ?? false {
				transition.maskFrame = webView.convert(webView.frame, to: nil)
			} else {
				transition.maskFrame = webView.convert(webView.safeAreaLayoutGuide.layoutFrame, to: nil)
			}
			
			transition.originImage = image
			
			coordinator.showFullScreenImage(image: image, imageTitle: clickMessage.imageTitle, transitioningDelegate: self)
		}
	}

	func stopMediaPlayback(_ webView: WKWebView) {
		webView.evaluateJavaScript("stopMediaPlayback();")
	}

	func cancelImageLoad(_ webView: WKWebView) {
		webView.evaluateJavaScript("cancelImageLoad();")
	}

	func configureTopShowBarsView() {
		topShowBarsView = UIView()
		topShowBarsView.backgroundColor = .clear
		topShowBarsView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(topShowBarsView)
		
		if AppDefaults.shared.articleFullscreenEnabled {
			topShowBarsViewConstraint = view.topAnchor.constraint(equalTo: topShowBarsView.bottomAnchor, constant: -44.0)
		} else {
			topShowBarsViewConstraint = view.topAnchor.constraint(equalTo: topShowBarsView.bottomAnchor, constant: 0.0)
		}
		
		NSLayoutConstraint.activate([
			topShowBarsViewConstraint,
			view.leadingAnchor.constraint(equalTo: topShowBarsView.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: topShowBarsView.trailingAnchor),
			topShowBarsView.heightAnchor.constraint(equalToConstant: 44.0)
		])
		topShowBarsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
	}
	
	func configureBottomShowBarsView() {
		bottomShowBarsView = UIView()
		topShowBarsView.backgroundColor = .clear
		bottomShowBarsView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(bottomShowBarsView)
		if AppDefaults.shared.articleFullscreenEnabled {
			bottomShowBarsViewConstraint = view.bottomAnchor.constraint(equalTo: bottomShowBarsView.topAnchor, constant: 44.0)
		} else {
			bottomShowBarsViewConstraint = view.bottomAnchor.constraint(equalTo: bottomShowBarsView.topAnchor, constant: 0.0)
		}
		NSLayoutConstraint.activate([
			bottomShowBarsViewConstraint,
			view.leadingAnchor.constraint(equalTo: bottomShowBarsView.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: bottomShowBarsView.trailingAnchor),
			bottomShowBarsView.heightAnchor.constraint(equalToConstant: 44.0)
		])
		bottomShowBarsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
	}
	
	func configureContextMenuInteraction() {
		if isFullScreenAvailable {
			if navigationController?.isNavigationBarHidden ?? false {
				webView?.addInteraction(contextMenuInteraction)
			} else {
				webView?.removeInteraction(contextMenuInteraction)
			}
		}
	}
	
	func contextMenuPreviewProvider() -> UIViewController {
		let previewProvider = UIStoryboard.main.instantiateController(ofType: ContextMenuPreviewViewController.self)
		previewProvider.article = article
		return previewProvider
	}
	
	func prevArticleAction() -> UIAction? {
		guard coordinator.isPrevArticleAvailable else { return nil }
		let title = NSLocalizedString("Previous Article", comment: "Previous Article")
		return UIAction(title: title, image: AppAssets.prevArticleImage) { [weak self] action in
			self?.coordinator.selectPrevArticle()
		}
	}
	
	func nextArticleAction() -> UIAction? {
		guard coordinator.isNextArticleAvailable else { return nil }
		let title = NSLocalizedString("Next Article", comment: "Next Article")
		return UIAction(title: title, image: AppAssets.nextArticleImage) { [weak self] action in
			self?.coordinator.selectNextArticle()
		}
	}
	
	func toggleReadAction() -> UIAction? {
		guard let article = article, !article.status.read || article.isAvailableToMarkUnread else { return nil }
		
		let title = article.status.read ? NSLocalizedString("Mark as Unread", comment: "Mark as Unread") : NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let readImage = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
		return UIAction(title: title, image: readImage) { [weak self] action in
			self?.coordinator.toggleReadForCurrentArticle()
		}
	}

	func toggleStarredAction() -> UIAction {
		let starred = article?.status.starred ?? false
		let title = starred ? NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") : NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
		let starredImage = starred ? AppAssets.starOpenImage : AppAssets.starClosedImage
		return UIAction(title: title, image: starredImage) { [weak self] action in
			self?.coordinator.toggleStarredForCurrentArticle()
		}
	}

	func nextUnreadArticleAction() -> UIAction? {
		guard coordinator.isAnyUnreadAvailable else { return nil }
		let title = NSLocalizedString("Next Unread Article", comment: "Next Unread Article")
		return UIAction(title: title, image: AppAssets.nextUnreadArticleImage) { [weak self] action in
			self?.coordinator.selectNextUnread()
		}
	}
	
	func toggleArticleExtractorAction() -> UIAction {
		let extracted = articleExtractorButtonState == .on
		let title = extracted ? NSLocalizedString("Show Feed Article", comment: "Show Feed Article") : NSLocalizedString("Show Reader View", comment: "Show Reader View")
		let extractorImage = extracted ? AppAsset.articleExtractorOffSFImage : AppAsset.articleExtractorOnSFImage
		return UIAction(title: title, image: extractorImage) { [weak self] action in
			self?.toggleArticleExtractor()
		}
	}

	func shareAction() -> UIAction {
		let title = NSLocalizedString("Share", comment: "Share")
		return UIAction(title: title, image: AppAsset.shareImage) { [weak self] action in
			self?.showActivityDialog()
		}
	}

	// If the resource cannot be opened with an installed app, present the web view.
	func openURL(_ url: URL) {
		UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { didOpen in
			assert(Thread.isMainThread)
			guard didOpen == false else {
				return
			}
			let vc = SFSafariViewController(url: url)
			self.present(vc, animated: true)
		}
	}

}

// MARK: Find in Article

private struct FindInArticleOptions: Codable {
	var text: String
	var caseSensitive = false
	var regex = false
}

internal struct FindInArticleState: Codable {
	struct WebViewClientRect: Codable {
		let x: Double
		let y: Double
		let width: Double
		let height: Double
	}
	
	struct FindInArticleResult: Codable {
		let rects: [WebViewClientRect]
		let bounds: WebViewClientRect
		let index: UInt
		let matchGroups: [String]
	}
	
	let index: UInt?
	let results: [FindInArticleResult]
	let count: UInt
}

extension WebViewController {
	
	func searchText(_ searchText: String, completionHandler: @escaping (FindInArticleState) -> Void) {
		guard let json = try? JSONEncoder().encode(FindInArticleOptions(text: searchText)) else {
			return
		}
		let encoded = json.base64EncodedString()
		
		webView?.evaluateJavaScript("updateFind(\"\(encoded)\")") {
			(result, error) in
			guard error == nil,
				let b64 = result as? String,
				let rawData = Data(base64Encoded: b64),
				let findState = try? JSONDecoder().decode(FindInArticleState.self, from: rawData) else {
					return
			}
			
			completionHandler(findState)
		}
	}
	
	func endSearch() {
		webView?.evaluateJavaScript("endFind()")
	}
	
	func selectNextSearchResult() {
		webView?.evaluateJavaScript("selectNextResult()")
	}
	
	func selectPreviousSearchResult() {
		webView?.evaluateJavaScript("selectPreviousResult()")
	}
	
}
