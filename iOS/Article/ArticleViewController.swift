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
	@IBOutlet private weak var webViewContainer: UIView!
	@IBOutlet private weak var showNavigationView: UIView!
	@IBOutlet private weak var showToolbarView: UIView!
	@IBOutlet private weak var showNavigationViewConstraint: NSLayoutConstraint!
	@IBOutlet private weak var showToolbarViewConstraint: NSLayoutConstraint!
	
	private var articleExtractorButton: ArticleExtractorButton = {
		let button = ArticleExtractorButton(type: .system)
		button.frame = CGRect(x: 0, y: 0, width: 44.0, height: 44.0)
		button.setImage(AppAssets.articleExtractorOff, for: .normal)
		return button
	}()
	
	private var webView: WKWebView!
	private lazy var contextMenuInteraction = UIContextMenuInteraction(delegate: self)
	private var isFullScreenAvailable: Bool {
		return traitCollection.userInterfaceIdiom == .phone && coordinator.isRootSplitCollapsed
	}
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
	
	var restoreOffset = 0
	
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
			webView?.evaluateJavaScript("cancelImageLoad();")
			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasClicked)
			webView.configuration.userContentController.removeScriptMessageHandler(forName: MessageName.imageWasShown)
			webView.removeFromSuperview()
			ArticleViewControllerWebViewProvider.shared.enqueueWebView(webView)
			webView = nil
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(webFeedIconDidBecomeAvailable(_:)), name: .WebFeedIconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(avatarDidBecomeAvailable(_:)), name: .AvatarDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(faviconDidBecomeAvailable(_:)), name: .FaviconDidBecomeAvailable, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		articleExtractorButton.addTarget(self, action: #selector(toggleArticleExtractor(_:)), for: .touchUpInside)
		toolbarItems?.insert(UIBarButtonItem(customView: articleExtractorButton), at: 6)

		showNavigationView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
		showToolbarView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(showBars(_:))))
		
		ArticleViewControllerWebViewProvider.shared.dequeueWebView() { webView in
			
			self.webView = webView
			self.webViewContainer.addChildAndPin(webView)
			
			webView.translatesAutoresizingMaskIntoConstraints = false
			self.webViewContainer.addSubview(webView)
			NSLayoutConstraint.activate([
				self.webViewContainer.leadingAnchor.constraint(equalTo: webView.leadingAnchor),
				self.webViewContainer.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
				self.webViewContainer.topAnchor.constraint(equalTo: webView.topAnchor),
				self.webViewContainer.bottomAnchor.constraint(equalTo: webView.bottomAnchor)
			])
			
			webView.navigationDelegate = self
			webView.uiDelegate = self
			self.configureContextMenuInteraction()

			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasClicked)
			webView.configuration.userContentController.add(WrapperScriptMessageHandler(self), name: MessageName.imageWasShown)

			// Even though page.html should be loaded into this webview, we have to do it again
			// to work around this bug: http://www.openradar.me/22855188
			let url = Bundle.main.url(forResource: "page", withExtension: "html")!
			webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())

		}
		
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		if AppDefaults.articleFullscreenEnabled {
			hideBars()
		}
	}
	
	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(true)
		coordinator.isArticleViewControllerPending = false
	}
	
	override func viewSafeAreaInsetsDidChange() {
		// This will animate if the show/hide bars animation is happening.
		view.layoutIfNeeded()
	}
	
	func updateUI() {
		
		guard let article = currentArticle else {
			articleExtractorButton.isEnabled = false
			nextUnreadBarButtonItem.isEnabled = false
			prevArticleBarButtonItem.isEnabled = false
			nextArticleBarButtonItem.isEnabled = false
			readBarButtonItem.isEnabled = false
			starBarButtonItem.isEnabled = false
			actionBarButtonItem.isEnabled = false
			return
		}
		
		nextUnreadBarButtonItem.isEnabled = coordinator.isAnyUnreadAvailable
		prevArticleBarButtonItem.isEnabled = coordinator.isPrevArticleAvailable
		nextArticleBarButtonItem.isEnabled = coordinator.isNextArticleAvailable

		articleExtractorButton.isEnabled = true
		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true
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
			rendering = ArticleRenderer.articleHTML(article: article, style: style, useImageIcon: true)
		case .extracted(let article, let extractedArticle):
			rendering = ArticleRenderer.articleHTML(article: article, extractedArticle: extractedArticle, style: style, useImageIcon: true)
		}
		
		let templateData = TemplateData(style: rendering.style, body: rendering.html)
		
		let encoder = JSONEncoder()
		var render = "error();"
		if let data = try? encoder.encode(templateData) {
			let json = String(data: data, encoding: .utf8)!
			render = "render(\(json), \(restoreOffset));"
		}

		restoreOffset = 0
		
		ArticleViewControllerWebViewProvider.shared.articleIconSchemeHandler.currentArticle = currentArticle
		webView?.scrollView.setZoomScale(1.0, animated: false)
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
	
	@objc func willEnterForeground(_ note: Notification) {
		// The toolbar will come back on you if you don't hide it again
		if AppDefaults.articleFullscreenEnabled {
			hideBars()
		}
	}
	
	// MARK: Actions

	@objc func showBars(_ sender: Any) {
		showBars()
	}

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
	
	@IBAction func showActivityDialog(_ sender: Any) {
		showActivityDialog()
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
	
	func fullReload() {
		if let offset = webView?.scrollView.contentOffset.y {
			restoreOffset = Int(offset)
			webView?.reload()
		}
	}
	
}

// MARK: InteractiveNavigationControllerTappable

extension ArticleViewController: InteractiveNavigationControllerTappable {
	func didTapNavigationBar() {
		hideBars()
	}
}

// MARK: UIContextMenuInteractionDelegate

extension ArticleViewController: UIContextMenuInteractionDelegate {
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
			
			coordinator.showFullScreenImage(image: image, transitioningDelegate: self)
		}
	}
	
	func showActivityDialog() {
		guard let preferredLink = currentArticle?.preferredLink, let url = URL(string: preferredLink) else {
			return
		}
		
		let itemSource = ArticleActivityItemSource(url: url, subject: currentArticle!.title)
		let activityViewController = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
		activityViewController.popoverPresentationController?.barButtonItem = actionBarButtonItem
		present(activityViewController, animated: true)
	}
	
	func showBars() {
		if isFullScreenAvailable {
			AppDefaults.articleFullscreenEnabled = false
			coordinator.showStatusBar()
			showNavigationViewConstraint.constant = 0
			showToolbarViewConstraint.constant = 0
			navigationController?.setNavigationBarHidden(false, animated: true)
			navigationController?.setToolbarHidden(false, animated: true)
			configureContextMenuInteraction()
		}
	}
	
	func hideBars() {
		if isFullScreenAvailable {
			AppDefaults.articleFullscreenEnabled = true
			coordinator.hideStatusBar()
			showNavigationViewConstraint.constant = 44.0
			showToolbarViewConstraint.constant = 44.0
			navigationController?.setNavigationBarHidden(true, animated: true)
			navigationController?.setToolbarHidden(true, animated: true)
			configureContextMenuInteraction()
		}
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
		previewProvider.article = currentArticle
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
		let read = currentArticle?.status.read ?? false
		let title = read ? NSLocalizedString("Mark as Unread", comment: "Mark as Unread") : NSLocalizedString("Mark as Read", comment: "Mark as Read")
		let readImage = read ? AppAssets.circleClosedImage : AppAssets.circleOpenImage
		return UIAction(title: title, image: readImage) { [weak self] action in
			self?.coordinator.toggleReadForCurrentArticle()
		}
	}

	func toggleStarredAction() -> UIAction {
		let starred = currentArticle?.status.starred ?? false
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
		let extracted = articleExtractorButton.buttonState == .on
		let title = extracted ? NSLocalizedString("Show Feed Article", comment: "Show Feed Article") : NSLocalizedString("Show Reader View", comment: "Show Reader View")
		let extractorImage = extracted ? AppAssets.articleExtractorOffSF : AppAssets.articleExtractorOnSF
		return UIAction(title: title, image: extractorImage) { [weak self] action in
			self?.coordinator.toggleArticleExtractor()
		}
	}

	func shareAction() -> UIAction {
		let title = NSLocalizedString("Share", comment: "Share")
		return UIAction(title: title, image: AppAssets.shareImage) { [weak self] action in
			self?.showActivityDialog()
		}
	}
	
}
