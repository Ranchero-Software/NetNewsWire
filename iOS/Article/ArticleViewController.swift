//
//  ArticleViewController.swift
//  NetNewsWire
//
//  Created by Maurice Parker on 4/8/19.
//  Copyright © 2019 Ranchero Software. All rights reserved.
//

import UIKit
import os
import SafariServices
import WebKit
import RSCore
import Account
import Articles

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

	private var defaultControls: [UIBarButtonItem]?

	private var pageViewController: UIPageViewController!
	private var isPageTransitionInProgress = false
	private var pendingSetViewController: WebViewController?

	private var currentWebViewController: WebViewController? {
		return pageViewController?.viewControllers?.first as? WebViewController
	}

	private var articleExtractorButton: ArticleExtractorButton = {
		let button = ArticleExtractorButton(type: .system)
		button.frame = CGRect(x: 0, y: 0, width: 44.0, height: 44.0)
		button.setImage(Assets.Images.articleExtractorOff, for: .normal)
		if #unavailable(iOS 26) {
			button.tintColor = Assets.Colors.primaryAccent
		} else {
			button.tintColor = .label
		}
		return button
	}()

	private let fullScreenTapZone = UIView()
	private var horizontalToolbarItems: [UIBarButtonItem]?
	private var horizontalRightBarButtonItems: [UIBarButtonItem]?

	weak var coordinator: SceneCoordinator!

	private let poppableDelegate = PoppableGestureRecognizerDelegate()
	private weak var originalPopGestureRecognizerDelegate: UIGestureRecognizerDelegate?
	private static let logger = Logger(subsystem: Logger.nnwSubsystem, category: "ArticleViewController")

	var article: Article? {
		didSet {
			Self.logger.debug("ArticleViewController: article didSet: \(self.article?.accountID ?? "nil") \(self.article?.articleID ?? "nil") \(self.article?.title ?? "nil")")

			if oldValue != article {
				// The launch-restoration scroll position belongs only to the restored article.
				// <https://github.com/Ranchero-Software/NetNewsWire/issues/5243>
				restoreScrollPosition = nil
			}

			if let controller = currentWebViewController, controller.article != article {
				controller.setArticle(article)
				if isPageTransitionInProgress {
					// Calling setViewControllers during an active page transition trips a UIPageViewController
					// internal assertion (NSInternalInconsistencyException) and crashes the app. Stash the
					// controller and flush it from didFinishAnimating once the transition has ended.
					pendingSetViewController = controller
				} else {
					DispatchQueue.main.async {
						// You have to set the view controller to clear out the UIPageViewController child controller cache.
						// You also have to do it in an async call or you will get a strange assertion error.
						// Re-check the transition state: a user swipe between enqueue and execution can flip
						// isPageTransitionInProgress to true, and calling setViewControllers then would crash.
						if self.isPageTransitionInProgress {
							self.pendingSetViewController = controller
						} else {
							self.pageViewController.setViewControllers([controller], direction: .forward, animated: false, completion: nil)
							self.syncArticleExtractorButtonState()
						}
					}
				}
			}
			updateUI()
			syncArticleExtractorButtonState()
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

	override var keyCommands: [UIKeyCommand]? {
		AppCommands.keyCommands(for: .detail)
	}
	override var canBecomeFirstResponder: Bool {
		true
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		NotificationCenter.default.addObserver(self, selector: #selector(unreadCountDidChange(_:)), name: .UnreadCountDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(statusesDidChange(_:)), name: .StatusesDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(contentSizeCategoryDidChange(_:)), name: UIContentSizeCategory.didChangeNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(handleArticleSwipeNavigationEnabledDidChange(_:)), name: .articleSwipeNavigationEnabledDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)

		let appearance = UINavigationBarAppearance()
		appearance.configureWithDefaultBackground()
		navigationItem.standardAppearance = appearance
		navigationItem.scrollEdgeAppearance = appearance
		navigationItem.compactAppearance = appearance

		NSLayoutConstraint.activate([
			fullScreenTapZone.widthAnchor.constraint(equalToConstant: 150),
			fullScreenTapZone.heightAnchor.constraint(equalToConstant: 44)
		])
		fullScreenTapZone.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(didTapNavigationBar)))
		updateFullScreenTapZone()
		#if compiler(>=6.4.2)
		if #available(iOS 27.1, *) {
			registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) { (self: Self, _) in
				self.updateFullScreenTapZone()
				self.updateBarItemsForVerticalBar()
			}
		}
		#endif

		articleExtractorButton.addTarget(self, action: #selector(toggleArticleExtractor(_:)), for: .touchUpInside)
		let articleExtractorBarButtonItem = UIBarButtonItem(customView: articleExtractorButton)
		articleExtractorBarButtonItem.title = NSLocalizedString("Reader View", comment: "Reader View")

		if #available(iOS 26, *) {
			#if compiler(>=6.4)
			// visibilityPriority is new in iOS 27.
			if #available(iOS 27, *) {
				readBarButtonItem.visibilityPriority = .standard
				starBarButtonItem.visibilityPriority = .standard
				nextUnreadBarButtonItem.visibilityPriority = .high
				articleExtractorBarButtonItem.visibilityPriority = .low
				actionBarButtonItem.visibilityPriority = .high
			}
			#endif
			#if compiler(>=6.4.2)
			// A custom view’s axes can’t be inferred, so without this the button sits outside the vertical bar.
			if #available(iOS 27.1, *) {
				articleExtractorBarButtonItem.axisBehavior = .verticalPreferred
			}
			#endif
			toolbarItems?.insert(articleExtractorBarButtonItem, at: 5)
		} else {
			let flex = { UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil) }
			toolbarItems = [
				readBarButtonItem,
				flex(),
				starBarButtonItem,
				flex(),
				nextUnreadBarButtonItem,
				flex(),
				articleExtractorBarButtonItem,
				flex(),
				actionBarButtonItem
			]
		}
		horizontalToolbarItems = toolbarItems
		horizontalRightBarButtonItems = navigationItem.rightBarButtonItems
		updateBarItemsForVerticalBar()

		pageViewController = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal, options: [:])
		pageViewController.delegate = self
		updatePageViewControllerDataSource()

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
		if AppDefaults.logicalArticleFullscreenEnabled {
			controller.hideBars()
		}

		NotificationCenter.default.addObserver(self, selector: #selector(handleFindInArticle(_:)), name: .FindInArticle, object: nil)

		updateUI()
	}

	override func viewWillAppear(_ animated: Bool) {
		let hideToolbars = AppDefaults.logicalArticleFullscreenEnabled
		if hideToolbars {
			currentWebViewController?.hideBars()
		} else {
			currentWebViewController?.showBars()
		}
		super.viewWillAppear(animated)
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		if #available(iOS 26, *) {
			navigationController?.navigationBar.topItem?.subtitle = nil
		}
		coordinator.isArticleViewControllerPending = false
		// Scoped to the article screen — restored in viewDidDisappear.
		if let parentNavController = navigationController?.parent as? UINavigationController,
			let gestureRecognizer = parentNavController.interactivePopGestureRecognizer {
			if gestureRecognizer.delegate !== poppableDelegate {
				originalPopGestureRecognizerDelegate = gestureRecognizer.delegate
			}
			poppableDelegate.navigationController = parentNavController
			gestureRecognizer.delegate = poppableDelegate
		}
	}

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		// Pass animated: false — animating the nav bar / toolbar visibility change during the
		// disappear transition triggers an Auto Layout assertion (NSISEngine) and crashes.
		currentWebViewController?.restoreBars(animated: false)
	}

	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		restoreOriginalPopGestureRecognizerDelegate()
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

		nextUnreadBarButtonItem.isEnabled = coordinator.isNextUnreadAvailable
		prevArticleBarButtonItem.isEnabled = coordinator.isPrevArticleAvailable
		nextArticleBarButtonItem.isEnabled = coordinator.isNextArticleAvailable
		readBarButtonItem.isEnabled = true
		starBarButtonItem.isEnabled = true

		let permalinkPresent = article.preferredLink != nil
		articleExtractorButton.isEnabled = permalinkPresent && !AppDefaults.isDeveloperBuild
		actionBarButtonItem.isEnabled = permalinkPresent

		if article.status.read {
			readBarButtonItem.image = Assets.Images.circleOpen
			readBarButtonItem.isEnabled = article.isAvailableToMarkUnread
			readBarButtonItem.accLabelText = NSLocalizedString("Mark Article Unread", comment: "Mark Article Unread")
		} else {
			readBarButtonItem.image = Assets.Images.circleClosed
			readBarButtonItem.isEnabled = true
			readBarButtonItem.accLabelText = NSLocalizedString("Selected - Mark Article Unread", comment: "Selected - Mark Article Unread")
		}

		if article.status.starred {
			starBarButtonItem.image = Assets.Images.starClosed
			starBarButtonItem.accLabelText = NSLocalizedString("Selected - Star Article", comment: "Selected - Star Article")
		} else {
			starBarButtonItem.image = Assets.Images.starOpen
			starBarButtonItem.accLabelText = NSLocalizedString("Star Article", comment: "Star Article")
		}
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

	@objc func handleArticleSwipeNavigationEnabledDidChange(_ notification: Notification) {
		updatePageViewControllerDataSource()
	}

	/// A nil data source turns off swipe paging. `setViewControllers` still works.
	func updatePageViewControllerDataSource() {
		pageViewController.dataSource = AppDefaults.articleSwipeNavigationEnabled ? self : nil
	}

	@objc func willEnterForeground(_ note: Notification) {
		// The toolbar will come back on you if you don't hide it again
		if AppDefaults.logicalArticleFullscreenEnabled {
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

	func toggleReaderView() {
		currentWebViewController?.toggleArticleExtractor()
	}

	// MARK: Keyboard Shortcuts

	@objc func navigateToTimeline(_ sender: Any?) {
		coordinator.navigateToTimeline()
	}

	@objc func scrollLineDown(_ sender: Any?) {
		currentWebViewController?.scrollLineDown()
	}

	@objc func scrollLineUp(_ sender: Any?) {
		currentWebViewController?.scrollLineUp()
	}

	// MARK: API

	// Focus this view controller rather than the web view, since the web view is replaced on each article change.
	func focus() {
		becomeFirstResponder()
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
}

// MARK: Find in Article
public extension Notification.Name {
	static let FindInArticle = Notification.Name("FindInArticle")
}

extension ArticleViewController {

	@objc func handleFindInArticle(_ notification: Notification) {
		presentFindNavigator()
	}

	override func find(_ sender: Any?) {
		presentFindNavigator()
	}

	override func findNext(_ sender: Any?) {
		currentWebViewController?.findInteraction?.findNext()
	}

	override func findPrevious(_ sender: Any?) {
		currentWebViewController?.findInteraction?.findPrevious()
	}

	// The web view handles Use Selection for Find while it has focus. When this view controller
	// has focus instead, the web view isn’t in the responder chain, so pass it along.
	override func useSelectionForFind(_ sender: Any?) {
		currentWebViewController?.useSelectionForFind()
	}

	override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
		if action == #selector(useSelectionForFind(_:)) {
			return currentWebViewController?.canUseSelectionForFind ?? false
		}
		if action == #selector(find(_:)) || action == #selector(findNext(_:)) || action == #selector(findPrevious(_:)) {
			return currentWebViewController?.findInteraction != nil
		}
		return super.canPerformAction(action, withSender: sender)
	}
}

// MARK: WebViewControllerDelegate

extension ArticleViewController: WebViewControllerDelegate {

	func webViewController(_ webViewController: WebViewController, articleExtractorButtonStateDidUpdate buttonState: ArticleExtractorButtonState) {
		guard webViewController === currentWebViewController else {
			return
		}
		syncArticleExtractorButtonState()
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

	func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
		isPageTransitionInProgress = true
	}

	func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
		isPageTransitionInProgress = false

		if let pending = pendingSetViewController {
			pendingSetViewController = nil
			// Async because UIKit is still finishing the swipe — a synchronous
			// setViewControllers here triggers an assertion in _UIQueuingScrollView.
			DispatchQueue.main.async {
				if self.isPageTransitionInProgress {
					self.pendingSetViewController = pending
				} else {
					self.pageViewController.setViewControllers([pending], direction: .forward, animated: false, completion: nil)
					self.syncArticleExtractorButtonState()
				}
			}
		}

		syncArticleExtractorButtonState()

		guard finished, completed else { return }
		guard let article = currentWebViewController?.article else { return }

		coordinator.selectArticle(article, animations: [.select, .scroll, .navigation])
		syncArticleExtractorButtonState()

		for viewController in previousViewControllers {
			if let webViewController = viewController as? WebViewController {
				webViewController.stopWebViewActivity()
			}
		}
	}
}

// MARK: UIGestureRecognizerDelegate

extension ArticleViewController: UIGestureRecognizerDelegate {

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
		// Paging is the only thing to hold back near the left edge. Refusing every other
		// recognizer there also blocked the split view's reveal gesture, so an edge swipe
		// did nothing over the article while it still worked alongside the toolbars.
		guard otherGestureRecognizer === pageViewController.scrollViewInsidePageControl?.panGestureRecognizer else {
			return true
		}
		return gestureRecognizer.location(in: nil).x > 40
    }

}

// MARK: Private

private extension ArticleViewController {

	func presentFindNavigator() {
		currentWebViewController?.findInteraction?.presentFindNavigator(showingReplace: false)
	}

	func createWebViewController(_ article: Article?, updateView: Bool = true) -> WebViewController {
		let controller = WebViewController()
		controller.coordinator = coordinator
		controller.delegate = self
		controller.setArticle(article, updateView: updateView)
		return controller
	}

	/// No tap zone with a vertical bar (Duo) — it would be the only thing in the top bar.
	func updateFullScreenTapZone() {
		#if compiler(>=6.4.2)
		if #available(iOS 27.1, *), traitCollection.verticalBarEdge != .unspecified {
			navigationItem.titleView = nil
			return
		}
		#endif
		navigationItem.titleView = fullScreenTapZone
	}

	/// With a vertical bar (Duo), Next Unread moves up below Previous and Next Article, near mid-column where the thumb rests.
	/// <https://github.com/Ranchero-Software/NetNewsWire/issues/5566>
	func updateBarItemsForVerticalBar() {
		#if compiler(>=6.4.2)
		if #available(iOS 27.1, *), traitCollection.verticalBarEdge != .unspecified {
			toolbarItems = horizontalToolbarItems?.filter { $0 !== nextUnreadBarButtonItem }
			navigationItem.rightBarButtonItems = [nextUnreadBarButtonItem, .fixedSpace()] + (horizontalRightBarButtonItems ?? [])
			return
		}
		#endif
		toolbarItems = horizontalToolbarItems
		navigationItem.rightBarButtonItems = horizontalRightBarButtonItems
	}

	func syncArticleExtractorButtonState() {
		articleExtractorButton.buttonState = currentWebViewController?.articleExtractorButtonState ?? .off
	}

	func restoreOriginalPopGestureRecognizerDelegate() {
		guard let gestureRecognizer = poppableDelegate.navigationController?.interactivePopGestureRecognizer,
			gestureRecognizer.delegate === poppableDelegate else {
			return
		}
		gestureRecognizer.delegate = originalPopGestureRecognizerDelegate
	}

}
