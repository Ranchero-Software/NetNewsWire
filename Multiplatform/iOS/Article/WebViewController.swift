//
//  WebViewController.swift
//  Multiplatform iOS
//
//  Created by Maurice Parker on 7/6/20.
//  Copyright © 2020 Ranchero Software. All rights reserved.
//

import UIKit
import WebKit
import RSCore
import Account
import Articles
import SafariServices
import MessageUI

protocol WebViewControllerDelegate: AnyObject {
	func webViewController(_: WebViewController, articleExtractorButtonStateDidUpdate: ArticleExtractorButtonState)
}

class WebViewController: UIViewController {
	
	private struct MessageName {
		static let imageWasClicked = "imageWasClicked"
		static let imageWasShown = "imageWasShown"
		static let showFeedInspector = "showFeedInspector"
	}
	
	private var topShowBarsView: UIView!
	private var bottomShowBarsView: UIView!
	private var topShowBarsViewConstraint: NSLayoutConstraint!
	private var bottomShowBarsViewConstraint: NSLayoutConstraint!
	
	private var webView: PreloadedWebView? {
		guard view.subviews.count > 0 else { return nil }
		return view.subviews[0] as? PreloadedWebView
	}
	
//	private lazy var contextMenuInteraction = UIContextMenuInteraction(delegate: self)
	private var isFullScreenAvailable: Bool {
		return AppDefaults.shared.articleFullscreenAvailable && traitCollection.userInterfaceIdiom == .phone // && coordinator.isRootSplitCollapsed
	}
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
	
	var sceneModel: SceneModel?
	weak var delegate: WebViewControllerDelegate?
	
	private(set) var article: Article?
	
	let scrollPositionQueue = CoalescingQueue(name: "Article Scroll Position", interval: 0.3, maxInterval: 0.3)
	var windowScrollY = 0
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		
		// Configure the tap zones
//		configureTopShowBarsView()
//		configureBottomShowBarsView()
		
		loadWebView()

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

	// MARK: Actions
	
//	@objc func showBars(_ sender: Any) {
//		showBars()
//	}
	
	// MARK: API

	func setArticle(_ article: Article?, updateView: Bool = true) {
		stopArticleExtractor()
		
		if article != self.article {
			self.article = article
			if updateView {
				if article?.webFeed?.isArticleExtractorAlwaysOn ?? false {
					startArticleExtractor()
				}
				windowScrollY = 0
				loadWebView()
			}
		}
		
	}
	
	func focus() {
		webView?.becomeFirstResponder()
	}

	func canScrollDown() -> Bool {
		guard let webView = webView else { return false }
		return webView.scrollView.contentOffset.y < finalScrollPosition()
	}

	func scrollPageDown() {
		guard let webView = webView else { return }
		
		let overlap = 2 * UIFont.systemFont(ofSize: UIFont.systemFontSize).lineHeight * UIScreen.main.scale
		let scrollToY: CGFloat = {
			let fullScroll = webView.scrollView.contentOffset.y + webView.scrollView.layoutMarginsGuide.layoutFrame.height - overlap
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
	
	func fullReload() {
		loadWebView(replaceExistingWebView: true)
	}

//	func showBars() {
//		AppDefaults.shared.articleFullscreenEnabled = false
//		coordinator.showStatusBar()
//		topShowBarsViewConstraint?.constant = 0
//		bottomShowBarsViewConstraint?.constant = 0
//		navigationController?.setNavigationBarHidden(false, animated: true)
//		navigationController?.setToolbarHidden(false, animated: true)
//		configureContextMenuInteraction()
//	}
//
//	func hideBars() {
//		if isFullScreenAvailable {
//			AppDefaults.shared.articleFullscreenEnabled = true
//			coordinator.hideStatusBar()
//			topShowBarsViewConstraint?.constant = -44.0
//			bottomShowBarsViewConstraint?.constant = 44.0
//			navigationController?.setNavigationBarHidden(true, animated: true)
//			navigationController?.setToolbarHidden(true, animated: true)
//			configureContextMenuInteraction()
//		}
//	}

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

// MARK: UIContextMenuInteractionDelegate

//extension WebViewController: UIContextMenuInteractionDelegate {
//	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
//
//		return UIContextMenuConfiguration(identifier: nil, previewProvider: contextMenuPreviewProvider) { [weak self] suggestedActions in
//			guard let self = self else { return nil }
//			var actions = [UIAction]()
//
//			if let action = self.prevArticleAction() {
//				actions.append(action)
//			}
//			if let action = self.nextArticleAction() {
//				actions.append(action)
//			}
//			if let action = self.toggleReadAction() {
//				actions.append(action)
//			}
//			actions.append(self.toggleStarredAction())
//			if let action = self.nextUnreadArticleAction() {
//				actions.append(action)
//			}
//			actions.append(self.toggleArticleExtractorAction())
//			actions.append(self.shareAction())
//
//			return UIMenu(title: "", children: actions)
//		}
//	}
//
//	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
//		coordinator.showBrowserForCurrentArticle()
//	}
//
//}

// MARK: WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
	
	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		for (index, view) in view.subviews.enumerated() {
			if index != 0, let oldWebView = view as? PreloadedWebView {
				oldWebView.removeFromSuperview()
			}
		}
	}
	
	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		
		if navigationAction.navigationType == .linkActivated {
			guard let url = navigationAction.request.url else {
				decisionHandler(.allow)
				return
			}
			
			let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
			if components?.scheme == "http" || components?.scheme == "https" {
				decisionHandler(.cancel)
				
				// If the resource cannot be opened with an installed app, present the web view.
				UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { didOpen in
					assert(Thread.isMainThread)
					guard didOpen == false else {
						return
					}
					let vc = SFSafariViewController(url: url)
					self.present(vc, animated: true)
				}
			} else if components?.scheme == "mailto" {
				decisionHandler(.cancel)
				
				guard let emailAddress = url.percentEncodedEmailAddress else {
					return
				}
				
				if UIApplication.shared.canOpenURL(emailAddress) {
					UIApplication.shared.open(emailAddress, options: [.universalLinksOnly : false], completionHandler: nil)
				} else {
					let alert = UIAlertController(title: NSLocalizedString("Error", comment: "Error"), message: NSLocalizedString("This device cannot send emails.", comment: "This device cannot send emails."), preferredStyle: .alert)
					alert.addAction(.init(title: NSLocalizedString("Dismiss", comment: "Dismiss"), style: .cancel, handler: nil))
					self.present(alert, animated: true, completion: nil)
				}
			} else if components?.scheme == "tel" {
				decisionHandler(.cancel)
				
				if UIApplication.shared.canOpenURL(url) {
					UIApplication.shared.open(url, options: [.universalLinksOnly : false], completionHandler: nil)
				}
				
			} else {
				decisionHandler(.allow)
			}
		} else {
			decisionHandler(.allow)
		}
	}

	func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
		fullReload()
	}
	
}

// MARK: WKUIDelegate

extension WebViewController: WKUIDelegate {
	func webView(_ webView: WKWebView, contextMenuForElement elementInfo: WKContextMenuElementInfo, willCommitWithAnimator animator: UIContextMenuInteractionCommitAnimating) {
		// We need to have at least an unimplemented WKUIDelegate assigned to the WKWebView.  This makes the
		// link preview launch Safari when the link preview is tapped.  In theory, you shoud be able to get
		// the link from the elementInfo above and transition to SFSafariViewController instead of launching
		// Safari.  As the time of this writing, the link in elementInfo is always nil.  ¯\_(ツ)_/¯
	}
}

// MARK: WKScriptMessageHandler

extension WebViewController: WKScriptMessageHandler {

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		switch message.name {
		case MessageName.imageWasShown:
			clickedImageCompletion?()
		case MessageName.imageWasClicked:
			imageWasClicked(body: message.body as? String)
		case MessageName.showFeedInspector:
			return
//			if let webFeed = article?.webFeed {
//				coordinator.showFeedInspector(for: webFeed)
//			}
		default:
			return
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
		
		sceneModel?.webViewProvider?.dequeueWebView() { webView in
			
			webView.ready {
				
				// Add the webview
				webView.translatesAutoresizingMaskIntoConstraints = false
				self.view.insertSubview(webView, at: 0)
				NSLayoutConstraint.activate([
					self.view.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
					self.view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
					self.view.topAnchor.constraint(equalTo: webView.topAnchor),
					self.view.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
				])
			
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
	//			self.configureContextMenuInteraction()

				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)
				webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.showFeedInspector)

				self.renderPage(webView)
				
			}
			
		}
		
	}

	func renderPage(_ webView: PreloadedWebView?) {
		guard let webView = webView else { return }
		 
		let style = ArticleStylesManager.shared.currentStyle
		let rendering: ArticleRenderer.Rendering

		if let articleExtractor = articleExtractor, articleExtractor.state == .processing {
			rendering = ArticleRenderer.loadingHTML(style: style)
		} else if let articleExtractor = articleExtractor, articleExtractor.state == .failedToParse, let article = article {
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		} else if let article = article, let extractedArticle = extractedArticle {
			if isShowingExtractedArticle {
				rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style)
			} else {
				rendering = ArticleRenderer.articleHTML(article: article, style: style)
			}
		} else if let article = article {
			rendering = ArticleRenderer.articleHTML(article: article, style: style)
		} else {
			rendering = ArticleRenderer.noSelectionHTML(style: style)
		}
		
		let substitutions = [
			"title": rendering.title,
			"baseURL": rendering.baseURL,
			"style": rendering.style,
			"body": rendering.html,
			"windowScrollY": String(windowScrollY)
		]

		let html = try! MacroProcessor.renderedText(withTemplate: ArticleRenderer.page.html, substitutions: substitutions)
		webView.loadHTMLString(html, baseURL: ArticleRenderer.page.baseURL)
		
	}
	
	func finalScrollPosition() -> CGFloat {
		guard let webView = webView else { return 0 }
		return webView.scrollView.contentSize.height - webView.scrollView.bounds.height + webView.scrollView.safeAreaInsets.bottom
	}
	
	func startArticleExtractor() {
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
			
//			coordinator.showFullScreenImage(image: image, imageTitle: clickMessage.imageTitle, transitioningDelegate: self)
		}
	}

	func stopMediaPlayback(_ webView: WKWebView) {
		webView.evaluateJavaScript("stopMediaPlayback();")
	}

	func cancelImageLoad(_ webView: WKWebView) {
		webView.evaluateJavaScript("cancelImageLoad();")
	}

//	func configureTopShowBarsView() {
//		topShowBarsView = UIView()
//		topShowBarsView.backgroundColor = .clear
//		topShowBarsView.translatesAutoresizingMaskIntoConstraints = false
//		view.addSubview(topShowBarsView)
//
//		if AppDefaults.shared.articleFullscreenEnabled {
//			topShowBarsViewConstraint = view.topAnchor.constraint(equalTo: topShowBarsView.bottomAnchor, constant: -44.0)
//		} else {
//			topShowBarsViewConstraint = view.topAnchor.constraint(equalTo: topShowBarsView.bottomAnchor, constant: 0.0)
//		}
//
//		NSLayoutConstraint.activate([
//			topShowBarsViewConstraint,
//			view.leadingAnchor.constraint(equalTo: topShowBarsView.leadingAnchor),
//			view.trailingAnchor.constraint(equalTo: topShowBarsView.trailingAnchor),
//			topShowBarsView.heightAnchor.constraint(equalToConstant: 44.0)
//		])
//		topShowBarsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
//	}
//
//	func configureBottomShowBarsView() {
//		bottomShowBarsView = UIView()
//		topShowBarsView.backgroundColor = .clear
//		bottomShowBarsView.translatesAutoresizingMaskIntoConstraints = false
//		view.addSubview(bottomShowBarsView)
//		if AppDefaults.shared.articleFullscreenEnabled {
//			bottomShowBarsViewConstraint = view.bottomAnchor.constraint(equalTo: bottomShowBarsView.topAnchor, constant: 44.0)
//		} else {
//			bottomShowBarsViewConstraint = view.bottomAnchor.constraint(equalTo: bottomShowBarsView.topAnchor, constant: 0.0)
//		}
//		NSLayoutConstraint.activate([
//			bottomShowBarsViewConstraint,
//			view.leadingAnchor.constraint(equalTo: bottomShowBarsView.leadingAnchor),
//			view.trailingAnchor.constraint(equalTo: bottomShowBarsView.trailingAnchor),
//			bottomShowBarsView.heightAnchor.constraint(equalToConstant: 44.0)
//		])
//		bottomShowBarsView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
//	}
	
//	func configureContextMenuInteraction() {
//		if isFullScreenAvailable {
//			if navigationController?.isNavigationBarHidden ?? false {
//				webView?.addInteraction(contextMenuInteraction)
//			} else {
//				webView?.removeInteraction(contextMenuInteraction)
//			}
//		}
//	}
//
//	func contextMenuPreviewProvider() -> UIViewController {
//		let previewProvider = UIStoryboard.main.instantiateController(ofType: ContextMenuPreviewViewController.self)
//		previewProvider.article = article
//		return previewProvider
//	}
//
//	func prevArticleAction() -> UIAction? {
//		guard coordinator.isPrevArticleAvailable else { return nil }
//		let title = NSLocalizedString("Previous Article", comment: "Previous Article")
//		return UIAction(title: title, image: AppAssets.prevArticleImage) { [weak self] action in
//			self?.coordinator.selectPrevArticle()
//		}
//	}
//
//	func nextArticleAction() -> UIAction? {
//		guard coordinator.isNextArticleAvailable else { return nil }
//		let title = NSLocalizedString("Next Article", comment: "Next Article")
//		return UIAction(title: title, image: AppAssets.nextArticleImage) { [weak self] action in
//			self?.coordinator.selectNextArticle()
//		}
//	}
//
//	func toggleReadAction() -> UIAction? {
//		guard let article = article, !article.status.read || article.isAvailableToMarkUnread else { return nil }
//
//		let title = article.status.read ? NSLocalizedString("Mark as Unread", comment: "Mark as Unread") : NSLocalizedString("Mark as Read", comment: "Mark as Read")
//		let readImage = article.status.read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
//		return UIAction(title: title, image: readImage) { [weak self] action in
//			self?.coordinator.toggleReadForCurrentArticle()
//		}
//	}
//
//	func toggleStarredAction() -> UIAction {
//		let starred = article?.status.starred ?? false
//		let title = starred ? NSLocalizedString("Mark as Unstarred", comment: "Mark as Unstarred") : NSLocalizedString("Mark as Starred", comment: "Mark as Starred")
//		let starredImage = starred ? AppAssets.starOpenImage : AppAssets.starClosedImage
//		return UIAction(title: title, image: starredImage) { [weak self] action in
//			self?.coordinator.toggleStarredForCurrentArticle()
//		}
//	}
//
//	func nextUnreadArticleAction() -> UIAction? {
//		guard coordinator.isAnyUnreadAvailable else { return nil }
//		let title = NSLocalizedString("Next Unread Article", comment: "Next Unread Article")
//		return UIAction(title: title, image: AppAssets.nextUnreadArticleImage) { [weak self] action in
//			self?.coordinator.selectNextUnread()
//		}
//	}
//
//	func toggleArticleExtractorAction() -> UIAction {
//		let extracted = articleExtractorButtonState == .on
//		let title = extracted ? NSLocalizedString("Show Feed Article", comment: "Show Feed Article") : NSLocalizedString("Show Reader View", comment: "Show Reader View")
//		let extractorImage = extracted ? AppAssets.articleExtractorOffSF : AppAssets.articleExtractorOnSF
//		return UIAction(title: title, image: extractorImage) { [weak self] action in
//			self?.toggleArticleExtractor()
//		}
//	}
//
//	func shareAction() -> UIAction {
//		let title = NSLocalizedString("Share", comment: "Share")
//		return UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
//			self?.showActivityDialog()
//		}
//	}
	
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

