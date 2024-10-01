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
import ArticleExtractor

final class ArticleViewController: UIViewController {
	
	typealias State = (extractedArticle: ExtractedArticle?,
		isShowingExtractedArticle: Bool,
		articleExtractorButtonState: ArticleExtractorButtonState,
		windowScrollY: Int)

	@IBOutlet private weak var nextUnreadBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var prevArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var nextArticleBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var readBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var starBarButtonItem: UIBarButtonItem!
	@IBOutlet private weak var actionBarButtonItem: UIBarButtonItem!
	
	@IBOutlet private var searchBar: ArticleSearchBar!
	@IBOutlet private var searchBarBottomConstraint: NSLayoutConstraint!
	private var defaultControls: [UIBarButtonItem]?
	
	private var pageViewController: UIPageViewController!
	
	private var currentWebViewController: WebViewController? {
		return pageViewController?.viewControllers?.first as? WebViewController
	}
	
	private var articleExtractorButton: ArticleExtractorButton = {
		let button = ArticleExtractorButton(type: .system)
		button.frame = CGRect(x: 0, y: 0, width: 44.0, height: 44.0)
		button.setImage(AppAsset.articleExtractorOffImage, for: .normal)
		return button
	}()
	
	weak var coordinator: SceneCoordinator!
	
	private let poppableDelegate = PoppableGestureRecognizerDelegate()

	var article: Article? {
		didSet {
			if let controller = currentWebViewController, controller.article != article {
				controller.setArticle(article)
				DispatchQueue.main.async {
					// You have to set the view controller to clear out the UIPageViewController child controller cache.
					// You also have to do it in an async call or you will get a strange assertion error.
					self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
				}
			}
			updateUI()
		}
	}
	
	var restoreScrollPosition: (isShowingExtractedArticle: Bool, articleWindowScrollY: Int)? {
		didSet {
			if let rsp = restoreScrollPosition {
				currentWebViewController?.setScrollPosition(isShowingExtractedArticle: rsp.isShowingExtractedArticle, articleWindowScrollY: rsp.articleWindowScrollY)
			}
		}
	}
	
	var currentState: State? {
		guard let controller = currentWebViewController else { return nil}
		return State(extractedArticle: controller.extractedArticle,
					 isShowingExtractedArticle: controller.isShowingExtractedArticle,
					 articleExtractorButtonState: controller.articleExtractorButtonState,
					 windowScrollY: controller.windowScrollY)
	}
	
	var restoreState: State?
	
	private let keyboardManager = KeyboardManager(type: .detail)
	override var keyCommands: [UIKeyCommand]? {
		return keyboardManager.keyCommands
	}
	
	private var lastKnownDisplayMode : UISplitViewController.DisplayMode?

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		let fullScreenTapZone = UIView()
		NSLayoutConstraint.activate([
			fullScreenTapZone.widthAnchor.constraint(equalToConstant: 150),
			fullScreenTapZone.heightAnchor.constraint(equalToConstant: 44)
		])
		fullScreenTapZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar)))
		navigationItem.titleView = fullScreenTapZone
		
		articleExtractorButton.addTarget(self, action: #selector(toggleArticleExtractor(_:)), for: .touchUpInside)
		toolbarItems?.insert(UIBarButtonItem(customView: articleExtractorButton), at: 6)

		if let parentNavController = navigationController?.parent as? UINavigationController {
			poppableDelegate.navigationController = parentNavController
			parentNavController.interactivePopGestureRecognizer?.delegate = poppableDelegate
		}

		navigationItem.leftItemsSupplementBackButton = true

		pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
		pageViewController.delegate = self
		pageViewController.dataSource = self

		// This code is to disallow paging if we scroll from the left edge.  If this code is removed
		// PoppableGestureRecognizerDelegate will allow us to both navigate back and page back at the
		// same time. That is really weird when it happens.
		let panGestureRecognizer = UIPanGestureRecognizer()
		panGestureRecognizer.delegate = self
		pageViewController.scrollViewInsidePageControl?.addGestureRecognizer(panGestureRecognizer)

		pageViewController.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(pageViewController.view)
		addChild(pageViewController!)
		NSLayoutConstraint.activate([
			view.leadingAnchor.constraint(equalTo: pageViewController.view.leadingAnchor),
			view.trailingAnchor.constraint(equalTo: pageViewController.view.trailingAnchor),
			view.topAnchor.constraint(equalTo: pageViewController.view.topAnchor),
			view.bottomAnchor.constraint(equalTo: pageViewController.view.bottomAnchor)
		])
				
		let controller: WebViewController
		if let state = restoreState {
			controller = createWebViewController(article, updateView: false)
			controller.extractedArticle = state.extractedArticle
			controller.isShowingExtractedArticle = state.isShowingExtractedArticle
			controller.articleExtractorButtonState = state.articleExtractorButtonState
			controller.windowScrollY = state.windowScrollY
		} else {
			controller = createWebViewController(article, updateView: true)
		}
		
		if let rsp = restoreScrollPosition {
			controller.setScrollPosition(isShowingExtractedArticle: rsp.isShowingExtractedArticle, articleWindowScrollY: rsp.articleWindowScrollY)
		}

		articleExtractorButton.buttonState = controller.articleExtractorButtonState
		
		self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
		if AppDefaults.shared.articleFullscreenEnabled {
			controller.hideBars()
		}
		
		// Search bar
		searchBar.translatesAutoresizingMaskIntoConstraints = false
		NotificationCenter.default.addObserver(self, selector: #selector(beginFind(_:)), name: .FindInArticle, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(endFind(_:)), name: .EndFindInArticle, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillChangeFrame(_:)), name: UIWindow.keyboardWillChangeFrameNotification, object: nil)
		searchBar.delegate = self
		view.bringSubviewToFront(searchBar)
		
		updateUI()
	}

	override func viewWillAppear(_ animated: Bool) {
		navigationController?.isToolbarHidden = false
		if AppDefaults.shared.articleFullscreenEnabled {
			currentWebViewController?.hideBars()
		}

		super.viewWillAppear(animated)
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		if searchBar != nil && !searchBar.isHidden {
			endFind()
		}
	}
	
	override func viewSafeAreaInsetsDidChange() {
		// This will animate if the show/hide bars animation is happening.
		view.layoutIfNeeded()
	}
	
	func updateUI() {
		
		guard let article = article else {
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
		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true
		
		let permalinkPresent = article.preferredLink != nil
		articleExtractorButton.isEnabled = permalinkPresent && !AppDefaults.shared.isDeveloperBuild
		actionBarButtonItem.isEnabled = permalinkPresent
		
		if article.status.read {
			readBarButtonItem.image = AppAssets.circleOpenImage
			readBarButtonItem.isEnabled = article.isAvailableToMarkUnread
			readBarButtonItem.accLabelText = NSLocalizedString("Mark Article Unread", comment: "Mark Article Unread")
		} else {
			readBarButtonItem.image = AppAssets.circleClosedImage
			readBarButtonItem.isEnabled = true
			readBarButtonItem.accLabelText = NSLocalizedString("Selected - Mark Article Unread", comment: "Selected - Mark Article Unread")
		}
		
		if article.status.starred {
			starBarButtonItem.image = AppAssets.starClosedImage
			starBarButtonItem.accLabelText = NSLocalizedString("Selected - Star Article", comment: "Selected - Star Article")
		} else {
			starBarButtonItem.image = AppAssets.starOpenImage
			starBarButtonItem.accLabelText = NSLocalizedString("Star Article", comment: "Star Article")
		}
	}

	override func contentScrollView(for edge: NSDirectionalRectEdge) -> UIScrollView? {
		return currentWebViewController?.webView?.scrollView
	}

	// MARK: Notifications
	
	@objc dynamic func unreadCountDidChange(_ notification: Notification) {
		updateUI()
	}
	
	@objc func statusesDidChange(_ note: Notification) {
		guard let articleIDs = note.userInfo?[Account.UserInfoKey.articleIDs] as? Set<String> else {
			return
		}
		guard let article = article else {
			return
		}
		if articleIDs.contains(article.articleID) {
			updateUI()
		}
	}

	@objc func contentSizeCategoryDidChange(_ note: Notification) {
		currentWebViewController?.fullReload()
	}
	
	@objc func willEnterForeground(_ note: Notification) {
		// The toolbar will come back on you if you don't hide it again
		if AppDefaults.shared.articleFullscreenEnabled {
			currentWebViewController?.hideBars()
		}
	}
	
	// MARK: Actions

	@objc func didTapNavigationBar() {
		currentWebViewController?.hideBars()
	}

	@objc func showBars(_ sender: Any) {
		currentWebViewController?.showBars()
	}

	@IBAction func toggleArticleExtractor(_ sender: Any) {
		currentWebViewController?.toggleArticleExtractor()
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
		currentWebViewController?.showActivityDialog(popOverBarButtonItem: actionBarButtonItem)
	}

	@objc func toggleReaderView(_ sender: Any?) {
		currentWebViewController?.toggleArticleExtractor()
	}
	
	// MARK: Keyboard Shortcuts

	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}
	
	// MARK: API

	func focus() {
		currentWebViewController?.focus()
	}

	func canScrollDown() -> Bool {
		return currentWebViewController?.canScrollDown() ?? false
	}

	func canScrollUp() -> Bool {
		return currentWebViewController?.canScrollUp() ?? false
	}

	func scrollPageDown() {
		currentWebViewController?.scrollPageDown()
	}

	func scrollPageUp() {
		currentWebViewController?.scrollPageUp()
	}
	
	func stopArticleExtractorIfProcessing() {
		currentWebViewController?.stopArticleExtractorIfProcessing()
	}

	func openInAppBrowser() {
		currentWebViewController?.openInAppBrowser()
	}
	
	func setScrollPosition(isShowingExtractedArticle: Bool, articleWindowScrollY: Int) {
		currentWebViewController?.setScrollPosition(isShowingExtractedArticle: isShowingExtractedArticle, articleWindowScrollY: articleWindowScrollY)
	}

	public func splitViewControllerWillChangeTo(displayMode: UISplitViewController.DisplayMode) {
		lastKnownDisplayMode = displayMode
	}
}

// MARK: Find in Article
public extension Notification.Name {
	static let FindInArticle = Notification.Name("FindInArticle")
	static let EndFindInArticle = Notification.Name("EndFindInArticle")
}

extension ArticleViewController: SearchBarDelegate {
	
	func searchBar(_ searchBar: ArticleSearchBar, textDidChange searchText: String) {
		currentWebViewController?.searchText(searchText) {
			found in
			searchBar.resultsCount = found.count
			
			if let index = found.index {
				searchBar.selectedResult = index + 1
			}
		}
	}
	
	func doneWasPressed(_ searchBar: ArticleSearchBar) {
		NotificationCenter.default.post(name: .EndFindInArticle, object: nil)
	}
	
	func nextWasPressed(_ searchBar: ArticleSearchBar) {
		if searchBar.selectedResult < searchBar.resultsCount {
			currentWebViewController?.selectNextSearchResult()
			searchBar.selectedResult += 1
		}
	}
	
	func previousWasPressed(_ searchBar: ArticleSearchBar) {
		if searchBar.selectedResult > 1 {
			currentWebViewController?.selectPreviousSearchResult()
			searchBar.selectedResult -= 1
		}
	}
}

extension ArticleViewController {
	
	@objc func beginFind(_ _: Any? = nil) {
		searchBar.isHidden = false
		navigationController?.setToolbarHidden(true, animated: true)
		currentWebViewController?.additionalSafeAreaInsets.bottom = searchBar.frame.height
		searchBar.becomeFirstResponder()
	}
	
	@objc func endFind(_ _: Any? = nil) {
		searchBar.resignFirstResponder()
		searchBar.isHidden = true
		navigationController?.setToolbarHidden(false, animated: true)
		currentWebViewController?.additionalSafeAreaInsets.bottom = 0
		currentWebViewController?.endSearch()
	}
	
	@objc func keyboardWillChangeFrame(_ notification: Notification) {
		if !searchBar.isHidden,
			let duration = notification.userInfo?[UIWindow.keyboardAnimationDurationUserInfoKey] as? Double,
			let curveRaw = notification.userInfo?[UIWindow.keyboardAnimationCurveUserInfoKey] as? UInt,
			let frame = notification.userInfo?[UIWindow.keyboardFrameEndUserInfoKey] as? CGRect {
			
			let curve = UIView.AnimationOptions(rawValue: curveRaw)
			let newHeight = view.safeAreaLayoutGuide.layoutFrame.maxY - frame.minY
			currentWebViewController?.additionalSafeAreaInsets.bottom = newHeight + searchBar.frame.height + 10
			self.searchBarBottomConstraint.constant = newHeight
			UIView.animate(withDuration: duration, delay: 0, options: curve, animations: {
				self.view.layoutIfNeeded()
			})
		}
	}
	
}


// MARK: WebViewControllerDelegate

extension ArticleViewController: WebViewControllerDelegate {
	
	func webViewController(_ webViewController: WebViewController, articleExtractorButtonStateDidUpdate buttonState: ArticleExtractorButtonState) {
		if webViewController === currentWebViewController {
			articleExtractorButton.buttonState = buttonState
		}
	}
	
}

// MARK: UIPageViewControllerDataSource

extension ArticleViewController: UIPageViewControllerDataSource {
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
		guard let webViewController = viewController as? WebViewController,
			let currentArticle = webViewController.article,
			let article = coordinator.findPrevArticle(currentArticle) else {
			return nil
		}
		return createWebViewController(article)
	}
	
	func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
		guard let webViewController = viewController as? WebViewController,
			let currentArticle = webViewController.article,
			let article = coordinator.findNextArticle(currentArticle) else {
			return nil
		}
		return createWebViewController(article)
	}
	
}

// MARK: UIPageViewControllerDelegate

extension ArticleViewController: UIPageViewControllerDelegate {

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		guard finished, completed else { return }
		guard let article = currentWebViewController?.article else { return }
		
		coordinator.selectArticle(article, animations: [.select, .scroll, .navigation])
		articleExtractorButton.buttonState = currentWebViewController?.articleExtractorButtonState ?? .off
		
		let webViewControllers = previousViewControllers.compactMap{ $0 as? WebViewController }
		for webViewController in webViewControllers {
			webViewController.stopWebViewActivity()
		}
	}
}

// MARK: UIGestureRecognizerDelegate

extension ArticleViewController: UIGestureRecognizerDelegate {
	
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		let point = gestureRecognizer.location(in: nil)
		if point.x > 40 {
			return true
		}
		return false
    }
	
}

// MARK: Private

private extension ArticleViewController {
	
	func createWebViewController(_ article: Article?, updateView: Bool = true) -> WebViewController {
		let controller = WebViewController()
		controller.coordinator = coordinator
		controller.delegate = self
		controller.setArticle(article, updateView: updateView)
		return controller
	}
	
}

private extension UIPageViewController {

	var scrollViewInsidePageControl: UIScrollView? {
		
		for view in view.subviews {
			if let scrollView = view as? UIScrollView {
				return scrollView
			}
		}
		return nil
	}
}
