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

protocol WebViewControllerDelegate: class {
	func webViewController(_: WebViewController, articleExtractorButtonStateDidUpdate: ArticleExtractorButtonState)
}

class WebViewController: UIViewController {
	
	private struct MessageName {
		static let imageWasClicked = "imageWasClicked"
		static let imageWasShown = "imageWasShown"
	}

	private var topShowBarsView: UIView!
	private var bottomShowBarsView: UIView!
	private var topShowBarsViewConstraint: NSLayoutConstraint!
	private var bottomShowBarsViewConstraint: NSLayoutConstraint!
	
	private var webView: WKWebView!
	private lazy var contextMenuInteraction = UIContextMenuInteraction(delegate: self)
	private var isFullScreenAvailable: Bool {
		return traitCollection.userInterfaceIdiom == .phone && coordinator.isRootSplitCollapsed
	}
	private lazy var transition = ImageTransition(controller: self)
	private var clickedImageCompletion: (() -> Void)?

	private var articleExtractor: ArticleExtractor? = nil
	private var extractedArticle: ExtractedArticle?
	private var isShowingExtractedArticle = false {
		didSet {
			if isShowingExtractedArticle != oldValue {
				reloadHTML()
			}
		}
	}

	var articleExtractorButtonState: ArticleExtractorButtonState = .off {
		didSet {
			delegate?.webViewController(self, articleExtractorButtonStateDidUpdate: articleExtractorButtonState)
		}
	}
	
	weak var coordinator: SceneCoordinator!
	weak var delegate: WebViewControllerDelegate?
	
	var article: Article? {
		didSet {
			stopArticleExtractor()
			if article?.webFeed?.isArticleExtractorAlwaysOn ?? false {
				startArticleExtractor()
			}
			if article != oldValue {
				reloadHTML()
			}
		}
	}
	
	var restoreOffset = 0
	
	deinit {
		if webView != nil  {
			webView?.evaluateJavaScript("cancelImageLoad();")
			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasClicked)
			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasShown)
			webView.removeFromSuperview()
			WebViewProvider.shared.enqueueWebView(webView)
			webView = nil
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)

		WebViewProvider.shared.dequeueWebView() { webView in
			
			// Add the webview
			self.webView = webView
			webView.translatesAutoresizingMaskIntoConstraints = false
			self.view.addSubview(webView)
			NSLayoutConstraint.activate([
				self.view.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
				self.view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
				self.view.topAnchor.constraint(equalTo: webView.topAnchor),
				self.view.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
			])

			self.configureTopShowBarsView()
			self.configureBottomShowBarsView()
			
			// Configure the webview
			webView.navigationDelegate = self
			webView.uiDelegate = self
			self.configureContextMenuInteraction()

			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)

			// Even though page.html should be loaded into this webview, we have to do it again
			// to work around this bug: http://www.openradar.me/22855188
			let url = Bundle.main.url(forResource: "page", withExtension: "html")!
			webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()
		}
		
	}

	func reloadHTML() {
		guard let webView = webView else { return }
		
		let style = ArticleStylesManager.shared.currentStyle
		let rendering: ArticleRenderer.Rendering

		if let articleExtractor = articleExtractor, articleExtractor.state == .processing {
			rendering = ArticleRenderer.loadingHTML(style: style)
		} else if let article = article, let extractedArticle = extractedArticle {
			if isShowingExtractedArticle {
				rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style, useImageIcon: true)
			} else {
				rendering = ArticleRenderer.articleHTML(article: article, style: style, useImageIcon: true)
			}
		} else if let article = article {
			rendering = ArticleRenderer.articleHTML(article: article, style: style, useImageIcon: true)
		} else {
			rendering = ArticleRenderer.noSelectionHTML(style: style)
		}
		
		let templateData = TemplateData(style: rendering.style, body: rendering.html)
		
		let encoder = JSONEncoder()
		var render = "error();"
		if let data = try? encoder.encode(templateData) {
			let json = String(data: data, encoding: .utf8)!
			render = "render(\(json), \(restoreOffset));"
		}

		restoreOffset = 0
		
		WebViewProvider.shared.articleIconSchemeHandler.currentArticle = article
		webView.scrollView.setZoomScale(1.0, animated: false)
		webView.evaluateJavaScript(render)
		
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

	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		reloadHTML()
	}
	
	// MARK: Actions
	
	@objc func showBars(_ sender: Any) {
		showBars()
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
	
	func fullReload() {
		if let offset = webView?.scrollView.contentOffset.y {
			restoreOffset = Int(offset)
			webView?.reload()
		}
	}

	func showBars() {
		if isFullScreenAvailable {
			AppDefaults.articleFullscreenEnabled = false
			coordinator.showStatusBar()
			topShowBarsViewConstraint?.constant = 0
			bottomShowBarsViewConstraint?.constant = 0
			navigationController?.setNavigationBarHidden(false, animated: true)
			navigationController?.setToolbarHidden(false, animated: true)
			configureContextMenuInteraction()
		}
	}
		
	func hideBars() {
		if isFullScreenAvailable {
			AppDefaults.articleFullscreenEnabled = true
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
			return
		}

		guard !isShowingExtractedArticle else {
			isShowingExtractedArticle = false
			articleExtractorButtonState = .off
			return
		}

		if let articleExtractor = articleExtractor {
			if article.preferredLink == articleExtractor.articleLink {
				isShowingExtractedArticle = true
				articleExtractorButtonState = .on
			}
		} else {
			startArticleExtractor()
		}

	}
	
	func showActivityDialog(popOverBarButtonItem: UIBarButtonItem? = nil) {
		guard let preferredLink = article?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		
		let itemSource = ArticleActivityItemSource(url: url, subject: article!.title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: [OpenInSafariActivity()])
		activityViewController.popoverPresentationController?.barButtonItem = popOverBarButtonItem
		present(activityViewController, animated: true)
	}
	
}

// MARK: ArticleExtractorDelegate

extension WebViewController: ArticleExtractorDelegate {

	func articleExtractionDidFail(with: Error) {
		stopArticleExtractor()
		articleExtractorButtonState = .error
	}

	func articleExtractionDidComplete(extractedArticle: ExtractedArticle) {
		if articleExtractor?.state != .cancelled {
			self.extractedArticle = extractedArticle
			isShowingExtractedArticle = true
			articleExtractorButtonState = .on
		}
	}

}

// MARK: UIContextMenuInteractionDelegate

extension WebViewController: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
	
		return UIContextMenuConfiguration(identifier: nil, previewProvider: contextMenuPreviewProvider) { [weak self] suggestedActions in
			guard let self = self else { return nil }
			var actions = [UIAction]()
			
			if let action = self.prevArticleAction() {
				actions.append(action)
			}
			if let action = self.nextArticleAction() {
				actions.append(action)
			}
			actions.append(self.toggleReadAction())
			actions.append(self.toggleStarredAction())
			if let action = self.nextUnreadArticleAction() {
				actions.append(action)
			}
			actions.append(self.toggleArticleExtractorAction())
			actions.append(self.shareAction())
			
			return UIMenu(title: "", children: actions)
        }
    }
	
	func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
		coordinator.showBrowserForCurrentArticle()
	}
	
}

// MARK: WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {
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
		self.reloadHTML()
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
	let imageTitle: String?
	let imageURL: String
}

// MARK: Private

private extension WebViewController {

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
		webView?.evaluateJavaScript("reloadArticleImage()")
	}
	
	func imageWasClicked(body: String?) {
		guard let body = body,
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
	
	func configureTopShowBarsView() {
		topShowBarsView = UIView()
		topShowBarsView.backgroundColor = .clear
		topShowBarsView.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(topShowBarsView)
		
		if AppDefaults.articleFullscreenEnabled {
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
		if AppDefaults.articleFullscreenEnabled {
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
	
	func toggleReadAction() -> UIAction {
		let read = article?.status.read ?? false
		let title = read ? NSLocalizedString("Mark as Unread", comment: "Mark as Unread") : NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let readImage = read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
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
		let extractorImage = extracted ? AppAssets.articleExtractorOffSF : AppAssets.articleExtractorOnSF
		return UIAction(title: title, image: extractorImage) { [weak self] action in
			self?.toggleArticleExtractor()
		}
	}

	func shareAction() -> UIAction {
		let title = NSLocalizedString("Share", comment: "Share")
		return UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
			self?.showActivityDialog()
		}
	}
	
}
